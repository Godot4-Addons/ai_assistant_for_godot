@tool
extends Node
class_name SSEClient

signal chunk_received(chunk: String)
signal request_completed(full_response: String)
signal error_occurred(error_message: String)

var _http_client: HTTPClient
var _stream_thread: Thread
var _thread_mutex: Mutex = Mutex.new()
var _is_requesting: bool = false
var _full_response: String = ""
var _url: String = ""
var _headers: PackedStringArray = []
var _body: String = ""

func request(url: String, headers: PackedStringArray, method: int = HTTPClient.METHOD_POST, body: String = ""):
	if _is_requesting:
		push_warning("SSEClient is already processing a request")
		return
		
	_url = url
	_headers = headers
	_body = body
	_full_response = ""
	_is_requesting = true
	
	_stream_thread = Thread.new()
	_stream_thread.start(_process_request_wrapper)

func _process_request_wrapper():
	_process_request()
	call_deferred("_on_thread_finished")

func is_active() -> bool:
	return _is_requesting

func cancel():
	_is_requesting = false
	if _http_client:
		_http_client.close()
	if _stream_thread and _stream_thread.is_started():
		_stream_thread.wait_to_finish()
		_stream_thread = null

func _process_request():
	_http_client = HTTPClient.new()
	
	# Parse URL manually for host and port
	var host = ""
	var port = -1
	var path = "/"
	var use_ssl = false
	
	if _url.begins_with("https://"):
		use_ssl = true
		var url_parts = _url.trim_prefix("https://").split("/", true, 1)
		host = url_parts[0]
		if url_parts.size() > 1:
			path = "/" + url_parts[1]
		port = 443
	elif _url.begins_with("http://"):
		var url_parts = _url.trim_prefix("http://").split("/", true, 1)
		host = url_parts[0]
		if url_parts.size() > 1:
			path = "/" + url_parts[1]
		port = 80
		
	if ":" in host:
		var hparts = host.split(":")
		host = hparts[0]
		port = hparts[1].to_int()
		
	var err = _http_client.connect_to_host(host, port, TLSOptions.client() if use_ssl else null)
	if err != OK:
		call_deferred("_emit_error", "Failed to connect to host: " + str(err))
		_is_requesting = false
		return
		
	while _http_client.get_status() == HTTPClient.STATUS_CONNECTING or _http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		_http_client.poll()
		OS.delay_msec(10)
		
	if _http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		call_deferred("_emit_error", "Failed to connect to host: " + str(_http_client.get_status()))
		_is_requesting = false
		return
		
	# Ensure content length is set for POST/body
	var final_headers = _headers.duplicate()
	if not _body.is_empty():
		var has_length = false
		for h in final_headers:
			if h.to_lower().begins_with("content-length:"):
				has_length = true
				break
		if not has_length:
			final_headers.append("Content-Length: " + str(_body.to_utf8_buffer().size()))
			
	# Enforce required streaming headers
	var has_accept = false
	for i in range(final_headers.size()):
		if final_headers[i].to_lower().begins_with("accept:"):
			final_headers[i] = "Accept: text/event-stream"
			has_accept = true
			break
	if not has_accept:
		final_headers.append("Accept: text/event-stream")
		
	err = _http_client.request(HTTPClient.METHOD_POST, path, final_headers, _body)
	if err != OK:
		call_deferred("_emit_error", "Failed to send HTTP request: " + str(err))
		_is_requesting = false
		return
		
	while _http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		_http_client.poll()
		OS.delay_msec(10)
		
	if _http_client.get_status() != HTTPClient.STATUS_BODY and _http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		call_deferred("_emit_error", "Failed to receive response Headers, status: " + str(_http_client.get_status()))
		_is_requesting = false
		return
		
	if _http_client.has_response():
		var response_code = _http_client.get_response_code()
		if response_code != 200:
			var error_body = ""
			while _http_client.get_status() == HTTPClient.STATUS_BODY:
				_http_client.poll()
				var chunk = _http_client.read_response_body_chunk()
				if chunk.size() > 0:
					error_body += chunk.get_string_from_utf8()
				OS.delay_msec(10)
			call_deferred("_emit_error", "HTTP Error " + str(response_code) + ": " + error_body)
			_is_requesting = false
			return
			
		var data_buffer = ""
		while _is_requesting:
			_http_client.poll()
			var status = _http_client.get_status()
			
			if status != HTTPClient.STATUS_BODY and status != HTTPClient.STATUS_CONNECTED:
				break
				
			if status == HTTPClient.STATUS_BODY:
				var chunk = _http_client.read_response_body_chunk()
				if chunk.size() > 0:
					var str_chunk = chunk.get_string_from_utf8()
					data_buffer += str_chunk
					
					# Process complete lines
					while "\n" in data_buffer:
						var split_idx = data_buffer.find("\n")
						var line = data_buffer.substr(0, split_idx).strip_edges()
						data_buffer = data_buffer.substr(split_idx + 1)
						
						if line.begins_with("data:"):
							var json_str = line.trim_prefix("data:").strip_edges()
							if json_str == "[DONE]":
								call_deferred("_emit_completed")
								_is_requesting = false
								_http_client.close()
								return
								
							call_deferred("_emit_chunk", json_str)
						
			OS.delay_msec(10)
			
	if _is_requesting:
		call_deferred("_emit_completed")
	
	_http_client.close()
	_is_requesting = false

func _on_thread_finished():
	_thread_mutex.lock()
	if _stream_thread and _stream_thread.is_started():
		_stream_thread.wait_to_finish()
		_stream_thread = null
	_thread_mutex.unlock()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_is_requesting = false
		if _http_client:
			_http_client.close()
		_on_thread_finished()

func _emit_chunk(json_str: String):
	chunk_received.emit(json_str)

func _emit_completed():
	request_completed.emit()

func _emit_error(msg: String):
	error_occurred.emit(msg)
