# This is a useless comment
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

# Note: Further processing might be needed to restore missing
# indentation inside functions if the source snippet lost its formatting.
