<div align="center">
  <img src="img/logo_static.svg" alt="AI Coding Assistant Logo" width="128" height="128">

# 🤖 AI Coding Assistant for Godot 4 — v3.2.0

[![Godot 4.x](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-3.2.0-green.svg)](https://github.com/Godot4-Addons/ai_assistant_for_godot/releases)

**A professional AI coding assistant plugin for Godot 4 with an agentic code system, syntax highlighting, and real-time streaming markdown rendering.**

</div>

<br>

<div align="center">
  <img src="img/banner.svg" alt="AI Coding Assistant Banner" width="100%">
</div>

<br>

<img src="img/image.png" alt="AI Coding Assistant in action" width="100%">

---

## ✨ What's New in v3.2.0

- 📜 **Multi-Session History** — Manage multiple independent conversations with ease. Sessions are stored persistently in `user://ai_sessions/`.
- ✏️ **Auto-Naming & Renaming** — New chats are automatically named from your first prompt. Manually rename or delete sessions directly from the settings panel.
- 🔙 **Apply/Undo Toggle** — Applied a code block but changed your mind? Click "Undo" to instantly revert using Godot's built-in Undo system.
- 🚀 **File Mentions (@file)** — Search and inject project file context directly into your prompts using the new `@` autocomplete.
- 🎨 **Premium Visual Identity** — Upgraded project branding with a minimalist vector logo and a refined cyan UI theme.
- 🛠️ **Stability & Safety** — Improved function detection for Smart Apply and fixed reported crashes in Godot 4.6.

- � **Syntax Highlighting** — GDScript, Python, JS/TS, C#, Bash, C/C++ with a Dracula-inspired palette
- 📦 **GitHub-Style Code Blocks** — Dark containers with rounded corners, language labels, and a 📋 **Copy** button
- 🧠 **Full Agentic System** — Multi-tool AI agent with project context, file patching, and semantic search
- � **Modular Persona System** — Swappable expert personas (Chat, Plan, Code)
- 📝 **Enhanced Markdown Rendering** — Fenced code blocks, nested lists, tables, blockquotes, checkboxes
- � **Permission Manager** — Approve or deny AI file operations
- ⚡ **Performance** — Intelligent caching, streaming without freezes, loop guards

### ⚠️ Known Limitations

- **Code/Auto mode** is not fully developed yet — may produce incomplete results on complex multi-file tasks
- **HuggingFace & Cohere** providers are less tested than Gemini

---

## 🚀 Quick Start

### 1. Install

```bash
git clone https://github.com/Godot4-Addons/ai_assistant_for_godot.git
cp -r ai_assistant_for_godot/addons/ai_coding_assistant your_project/addons/
```

### 2. Enable

1. Open your Godot project → **Project Settings > Plugins**
2. Enable **AI Coding Assistant**
3. The assistant dock appears in the editor

### 3. Configure

1. Click **⚙ Settings** in the dock
2. Select a provider (OpenRouter recommended)
3. Enter your API key — start coding!

> [!TIP]
> **OpenRouter** is the recommended provider as it gives you unified access to all top models (Claude 4.6, GPT-5.4, Gemini 3.1, etc.) through a single API key.

---

## 🎯 Core Features

### 🧠 Agentic AI System

| Feature                | Description                                                |
| ---------------------- | ---------------------------------------------------------- |
| **Multi-Tool Agent**   | Reads files, patches code, runs searches, creates files    |
| **Project Context**    | Automatically builds a blueprint of your project structure |
| **Semantic Search**    | Finds relevant code across your codebase                   |
| **Loop Guard**         | Prevents runaway agent loops with configurable limits      |
| **Permission Manager** | Review and approve AI file operations                      |

### 🎨 Syntax Highlighting

| Language      | Keywords | Types | Strings | Comments | Functions |
| ------------- | -------- | ----- | ------- | -------- | --------- |
| GDScript      | ✅       | ✅    | ✅      | ✅       | ✅        |
| Python        | ✅       | ✅    | ✅      | ✅       | ✅        |
| JavaScript/TS | ✅       | ✅    | ✅      | ✅       | ✅        |
| C#            | ✅       | ✅    | ✅      | ✅       | ✅        |
| Bash/Shell    | ✅       | —     | ✅      | ✅       | ✅        |
| C/C++         | ✅       | ✅    | ✅      | ✅       | ✅        |

### 📝 Markdown Rendering

- **Headers** (H1–H6) with configurable font sizes
- **Fenced code blocks** with language detection and syntax coloring
- **GitHub-style code containers** — dark panel, border, language label, copy button
- **Ordered & unordered lists** with nesting
- **Tables** with header formatting
- **Blockquotes**, **horizontal rules**, **checkboxes**
- **Inline formatting** — bold, italic, underline, strikethrough, code spans
- **Links & images**

### 🔌 AI Providers

| Provider        | Model          | Notes                                  |
| --------------- | -------------- | -------------------------------------- |
| **OpenRouter**  | Multiple       | **Recommended** — Access to all models |
| **Gemini**      | gemini-3.1     | Fast & accurate                        |
| **HuggingFace** | Various        | Free tier available                    |
| **Cohere**      | Command series | Enterprise-grade                       |

---

## 🏗️ Architecture

```
addons/ai_coding_assistant/
├── agent/               # Agentic AI system
│   ├── agent_loop.gd    # Main agent execution loop
│   ├── agent_context.gd # Project context builder
│   ├── agent_memory.gd  # Conversation memory
│   ├── tool_registry.gd # Tool definitions & execution
│   ├── loop_guard.gd    # Safety limits
│   └── permission_manager.gd
├── persona/             # Modular persona system
│   ├── persona_manager.gd
│   ├── chat_persona.gd
│   ├── code_persona.gd
│   └── plan_persona.gd
├── markdownlabel/       # Markdown rendering engine
│   ├── markdownlabel.gd # RichTextLabel extension
│   ├── markdown_parser.gd
│   └── syntax_highlighter.gd
├── ui/                  # UI components
│   ├── ai_assistant_dock.gd
│   ├── chat_message.gd  # GitHub-style message rendering
│   └── ui_theme.gd
└── editor/              # Editor integration
    └── editor_reader.gd
```

---

## 📱 Responsive Layout

| Screen Size             | Layout   | Features                        |
| ----------------------- | -------- | ------------------------------- |
| **Large (>1000px)**     | Expanded | Full features, generous spacing |
| **Medium (600–1000px)** | Balanced | Optimized for productivity      |
| **Small (400–600px)**   | Compact  | Auto-collapse, space efficient  |
| **Mobile (<400px)**     | Minimal  | Essential functions only        |

---

## ️ Development

### Requirements

- Godot 4.x (4.0+)
- Internet connection for AI features
- API key from a supported provider

### Contributing

We love community contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines and our [CONTRIBUTORS.md](CONTRIBUTORS.md) to see who has helped build this project.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## � License

MIT License — see [LICENSE](LICENSE) for details.

## � Credits

- **Godot Engine** — Juan Linietsky, Ariel Manzur & Contributors
- **MarkdownLabel** — Based on [daenvil/MarkdownLabel](https://github.com/daenvil/MarkdownLabel) (MIT)
- **Logo & Design** — [Grandpa EJ](https://github.com/gpbot-org)
- **AI Providers** — Google (Gemini), HuggingFace, Cohere, OpenRouter

---

<div align="center">

**Made with ❤️ for the Godot community by [Grandpa EJ](https://github.com/grandpaej)**

_Transform your Godot development with professional AI assistance!_ 🚀

</div>
