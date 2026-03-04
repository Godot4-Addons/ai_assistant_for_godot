# Changelog

All notable changes to the AI Coding Assistant for Godot 4 are documented here.

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

---

## [2.0.0] — 2026-02-28

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
