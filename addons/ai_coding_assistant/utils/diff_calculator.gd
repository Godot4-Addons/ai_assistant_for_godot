@tool
extends RefCounted
class_name AIDiffCalculator

static func compute_diff(original: PackedStringArray, modified: PackedStringArray) -> Array:
	var result = []
	var i = 0
	var j = 0

	while i < original.size() or j < modified.size():
		if i >= original.size():
			result.append({"type": "add", "text": modified[j]})
			j += 1
		elif j >= modified.size():
			result.append({"type": "remove", "text": original[i]})
			i += 1
		elif original[i] == modified[j]:
			i += 1
			j += 1
		else:
			var found = false
			for k in range(j + 1, min(j + 5, modified.size())):
				if original[i] == modified[k]:
					for l in range(j, k):
						result.append({"type": "add", "text": modified[l]})
					j = k
					found = true
					break
			if not found:
				var found_in_orig = false
				for k in range(i + 1, min(i + 5, original.size())):
					if modified[j] == original[k]:
						for l in range(i, k):
							result.append({"type": "remove", "text": original[l]})
						i = k
						found_in_orig = true
						break
				if not found_in_orig:
					result.append({"type": "modify", "text": "'" + original[i] + "' -> '" + modified[j] + "'"})
					i += 1
					j += 1
	return result
