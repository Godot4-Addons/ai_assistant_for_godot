with open("addons/ai_coding_assistant/markdown.gd", "r", encoding="utf-8") as f:
    text = f.read()

# Fix space omissions from the bad sed command
text = text.replace("const_", "const _")
text = text.replace("var_", "var _")
text = text.replace("func_", "func _")
text = text.replace(" : set =", " : set = _")
text = text.replace("\nif_", "\nif _")
text = text.replace(" return_", " return _")
text = text.replace(" in_", " in _")
text = text.replace(" for_", " for _")
text = text.replace(" elif_", " elif _")

# Also there were un-indented lines inside functions:
# It looks like the source had no indentation? Wait, the file snippet shows:
# 172: func _init(markdown_text: String = "") -> void:
# 173: bbcode_enabled = true
# Wait! In the view_file tool output I saw earlier, ALL the indentation was missing from the user's file!
# That's why it failed with "Expected indented block after function declaration."
