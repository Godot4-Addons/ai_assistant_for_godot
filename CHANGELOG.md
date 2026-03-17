# Changelog

All notable changes to the AI Coding Assistant for Godot 4 are documented here.

---

## [3.2.0] — 2026-03-18

### ✨ Added

- **Multi-Session Chat History** — Support for multiple independent conversations, stored and managed in `user://ai_sessions/`
- **Automatic Session Naming** — New chats are automatically named based on the first user prompt for better organization
- **Manual Session Management** — New Rename (✏️) and Delete (🗑️) controls added to the settings panel
- **Apply/Undo Toggle** — The "Apply" button now toggles to "Undo" after code is applied, allowing instant reversal using Godot's Undo system
- **File Mention System (@file)** — Integrated project-wide file search and context injection directly into chat prompts
- **New Premium Identity** — Upgraded project branding with a modern minimalist vector logo design
- **Persistent State** — All settings (API keys, models) and the last active session are now persisted across Godot restarts

### 🔧 Changed

- **Smart Apply Robustness** — Improved function detection using regex for more reliable code insertion
- **Stability Overhaul** — Refined "replace full script" logic to resolve reported crashes in Godot 4.6

### 🐛 Fixed

- **Nil Reference Crashes** — Resolved initialization race conditions where UI was accessed before setup
- **Parse Errors** — Fixed various GDScript parse errors related to type inference and duplicate declarations

---

## [3.1.0] — 2026-03-06

### ✨ Added

- **Real-time Markdown Streaming** — See beautiful markdown and syntax-highlighted code blocks generate live as the AI types
- **Apply Code Button** — Click "✨ Apply" on any generated code block to instantly insert (or replace selection) into your Godot script
- **Use Selection Workflow** — Highlight code in the Godot script editor and add it directly to your chat prompt with one click
- **Extensible Chat Modes** — Data-driven AI modes allowing easy backend expansion

### 🔧 Changed

- **Code Block Rendering** — Extracted into incrementally generated `PanelContainer` node structures for live rendering

### 🗑️ Removed

- **Inline Diff Viewer** — Removed as it became redundant with the new Apply Code functionality

---

## [3.0.0] — 2026-03-04

### ✨ Added

- **Syntax Highlighting Engine** — Regex-based tokenizer supporting GDScript, Python, JavaScript/TypeScript, C#, Bash/Shell, and C/C++ with Dracula-inspired color palette
- **GitHub-Style Code Block Containers** — Dark background, rounded corners, subtle border, language label header, and copy button with "✅ Copied!" feedback
- **Segment-Based Rendering** — `split_segments()` pre-parser splits markdown into text and code segments for proper container-based rendering
- **Standalone Syntax Highlighter** (`syntax_highlighter.gd`) — Extracted from parser, no `class_name`, safe `preload()` pattern
- **Text Selection & Copy** — `selection_enabled`, `context_menu_enabled`, smooth semi-transparent blue highlight
- **Full Agentic AI System** — Multi-tool agent loop with file read/write/patch, semantic search, project context builder
- **Modular Persona System** — Swappable Chat, Plan, and Code personas with `persona_manager.gd`
- **Permission Manager** — User approval for AI file operations
- **Loop Guard** — Configurable safety limits to prevent runaway agent loops
- **Agent Memory** — Persistent conversation memory with session save/load
- **Intelligent Project Caching** — `agent_context.gd` builds and caches project blueprints
- **OpenRouter Provider** — Additional AI model access

### 🔧 Changed

- **Markdown Parser** refactored from monolithic → modular rule-based → consolidated with regions (resolved Godot `preload()` circular dependency issues)
- **Code Block Rendering** — Switched from inline `[bgcolor]` BBCode to separate `PanelContainer` nodes
- **MarkdownLabel** decoupled from parser into `markdownlabel.gd` + `markdown_parser.gd`
- **Chat Messages** now use segment-based rendering with individual styled containers per code block
- **UI Theme** upgraded with syntax highlighting colors and code block styling
- Parser reduced from **970 → 685 lines** by extracting syntax highlighter (260 lines)

### 🐛 Fixed

- Unwanted line gaps in code blocks (main loop was adding `\n` for buffered lines)
- `SyntaxHighlighter` const shadowing Godot's native class → renamed to `CodeHighlighterScript`
- `escaped_kw` GDScript type inference failure → added explicit `String` type
- Circular `preload()` dependencies between parser and rule files
- Naming inconsistencies (`_CHECKBOX_KEY` vs `CHECKBOX_KEY`)
- Unicode UTF-8 parsing errors on binary files
- AI agent hangs and missing XML tool parsing
- Extreme UI freezing during code generation and streaming
- Freeze/crash on stop button — full robustness overhaul

### ⚠️ Known Limitations

- **Code/Auto mode** is not fully developed yet — agentic tool execution may produce incomplete results on complex multi-file tasks
- **Streaming mode** doesn't render markdown in real-time (only plain text until finalized)
- **No line numbers** in code blocks yet
- **No multi-block copy** — can only copy individual code blocks, not entire chat messages
- **HuggingFace & Cohere** providers are less tested than Gemini
- **Large projects** may cause slow initial context building on first use

---

## [2.0.0] — 2025-02-28

### ✨ Added

- Professional UI/UX with responsive design
- Enhanced markdown rendering (headers, lists, quotes, code blocks)
- Multi-provider AI support (Gemini, HuggingFace, Cohere)
- Flexible layout with resizable panels
- VS Code-inspired dark theme
- Multi-monitor and cross-platform support
- Chat history persistence
- Global context configuration
- Clear history functionality

### 🔧 Changed

- Complete UI redesign from basic to professional-grade
- Markdown renderer upgraded with tables, nested lists, blockquotes
- Code blocks with language detection

### 🐛 Fixed

- Property compatibility issues with Godot 4.x
- Syntax errors across codebase
- SSE polling loop restructured for stability

---

## [1.0.0] — Initial Release

### ✨ Added

- Basic AI chat integration
- Gemini API support
- Simple code generation
- GDScript assistance
- Editor dock panel
