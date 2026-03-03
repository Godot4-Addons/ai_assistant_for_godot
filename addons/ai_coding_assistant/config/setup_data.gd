@tool
extends RefCounted
class_name AISetupData

static func get_steps() -> Array:
	return [
		{
			"title": "Welcome to AI Coding Assistant!",
			"content": "[b]Welcome![/b] This guide will help you set up the AI Coding Assistant plugin."
		},
		{
			"title": "Step 1: Choose Your AI Provider",
			"content": "[b]Choose an AI Provider[/b]\n\nWe recommend starting with [b]Google Gemini[/b] (free and powerful)."
		},
		{
			"title": "Step 2: Configure the Plugin",
			"content": "[b]Configure Your Settings[/b]\n\n1. Look for the [b]\"AI Assistant\"[/b] dock on the left side of the editor."
		},
		{
			"title": "Step 3: Test Your Setup",
			"content": "[b]Test Your Configuration[/b]\n\nTry sending a message: \"Hello, can you help me with GDScript?\""
		}
	]
