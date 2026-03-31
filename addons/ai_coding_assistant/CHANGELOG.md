# Changelog

All notable changes to the AI Coding Assistant plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.3.0-rc1] - 2026-04-01

### Added
- Renamed assistant personas to **JUI**.
- Built-in support for Gemini 2.x and 3.x models (defaulting to `gemini-2.5-flash`).
- New JSON array streaming support in `SSEClient` for non-SSE providers like Gemini.

### Fixed
- Fixed Gemini HTTP 400 error caused by unsupported "stream" flag and incorrect endpoint.
- Fixed UI bug where the "Stop" button remained active after response completion.

### Changed
- Improved Settings UI: "Base URL" field is now hidden for builtin providers (Gemini, GPT, etc.).

## [1.0.0] - 2025-05-20

### Added
- Initial release of AI Coding Assistant for Godot 4.x
- Support for multiple AI providers (Google Gemini, Hugging Face, Cohere)
- Real-time AI chat interface
- Code generation and explanation features
- Quick action templates for common game development patterns
- Responsive UI design that adapts to different screen sizes
- Code diff viewer for reviewing AI-generated changes
- Persistent settings and chat history
- Comprehensive setup guide
- Keyboard shortcuts for efficient workflow
- Code templates for player movement, UI controllers, save systems, etc.
- Syntax validation and code improvement suggestions
- Context-aware AI assistance based on current project
- Export/import functionality for code snippets
- Dark theme optimized for coding
- Flexible dock layout with resizable panels
- Auto-collapse sections for small screens
- Line numbers and syntax highlighting options
- Word wrap toggle for chat and code areas
- Copy and save functionality for generated code

### Features
- **AI Chat**: Interactive conversation with AI for coding help
- **Code Generation**: Generate complete scripts and functions
- **Code Explanation**: Understand complex code with AI explanations  
- **Code Improvement**: Get optimization and best practice suggestions
- **Quick Actions**: Pre-built templates for common patterns
- **Template System**: Ready-to-use code templates
- **Diff Viewer**: Review changes before applying them
- **Context Analysis**: AI understands your project structure
- **Multi-Provider**: Support for multiple AI services
- **Responsive Design**: Works on any screen size
- **Persistent State**: Settings and layout are saved
- **Keyboard Shortcuts**: Efficient hotkey support

### Technical Details
- Built for Godot 4.x (4.0+)
- Uses modern GDScript syntax and features
- Implements proper error handling and validation
- Follows Godot plugin development best practices
- Includes comprehensive documentation
- Supports both light and dark themes
- Optimized for performance and memory usage

### API Providers
- **Google Gemini**: Primary recommended provider with generous free tier
- **Hugging Face**: Open-source models with free inference API
- **Cohere**: Advanced language models with free tier

### Code Templates
- Player Movement (2D/3D)
- UI Controller and Menu Management
- Save/Load System
- Audio Manager
- State Machine
- Inventory System
- Singleton/Autoload
- Input Handler
- Health System
- Scene Manager

### UI Features
- Collapsible sections for space efficiency
- Resizable splitter between chat and code areas
- Context menus for additional options
- Tooltip help for all buttons and features
- Status indicators for API connection
- Progress feedback for long operations
- Error messages with helpful context
- Success confirmations for completed actions

### Accessibility
- Keyboard navigation support
- Screen reader friendly labels
- High contrast color scheme
- Scalable font sizes
- Clear visual hierarchy
- Consistent interaction patterns

### Documentation
- Comprehensive README with setup instructions
- Built-in setup guide with step-by-step instructions
- Code examples and usage patterns
- Troubleshooting guide
- API provider comparison
- Keyboard shortcut reference
- Template documentation
- Contributing guidelines

### Known Issues
- None at release

### Compatibility
- Requires Godot 4.0 or later
- Tested on Windows, macOS, and Linux
- Works with all Godot 4.x project types
- Compatible with C# projects (GDScript features only)

### Performance
- Minimal impact on editor performance
- Efficient memory usage
- Fast response times for UI interactions
- Optimized API request handling
- Smart caching for improved responsiveness

### Security
- API keys stored securely in user settings
- No sensitive data transmitted beyond necessary API calls
- Local processing for syntax validation
- Secure HTTPS connections to AI providers
- No telemetry or usage tracking

### Future Plans
- Additional AI provider integrations
- Enhanced code analysis features
- More code templates and patterns
- Improved context understanding
- Plugin marketplace integration
- Community template sharing
- Advanced customization options
- Integration with version control systems

---

## Development Notes

### Version Numbering
- Major version: Breaking changes or significant new features
- Minor version: New features that are backward compatible
- Patch version: Bug fixes and small improvements

### Release Process
1. Update version numbers in plugin.cfg
2. Update CHANGELOG.md with new features and fixes
3. Test on multiple Godot versions
4. Create release tag and GitHub release
5. Submit to Godot Asset Library (if applicable)

### Contributing
See [README.md](README.md) for contribution guidelines and development setup instructions.

### Support
- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: Community support and questions
- Documentation: Comprehensive guides and examples
