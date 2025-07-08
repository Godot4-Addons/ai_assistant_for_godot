<div align="center">
  <img src="img/logo_static.svg" alt="AI Coding Assistant Logo" width="128" height="128">

  # 🤖 AI Coding Assistant for Godot 4 [v2.0.0] [Still on DEV MODE]

  [![Godot 4](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Version](https://img.shields.io/badge/Version-2.0.0-green.svg)](https://github.com/Godot4-Addons/ai_assistant_for_godot/releases)
</div>

A **professional-grade AI coding assistant** plugin for Godot 4 that transforms your development workflow with advanced features, responsive design, and enhanced markdown highlighting.

<div align="center">
  <img src="img/banner.svg" alt="AI Coding Assistant Banner" width="100%">
</div>

<img src="img/image.png" alt="AI Coding Assistant in action" width="100%">

## ✨ **Key Features**

### 🎯 **Advanced AI Integration**
- **Multiple AI Providers**: Gemini, HuggingFace, Cohere support
- **Smart Code Generation**: Context-aware code suggestions
- **Real-time Assistance**: Instant help with coding problems
- **Multi-language Support**: GDScript, Python, JavaScript, JSON

### 🎨 **Professional UI/UX**
- **Responsive Design**: Adapts to any screen size automatically
- **Enhanced Markdown**: VS Code-inspired syntax highlighting
- **Flexible Layout**: Resizable panels and collapsible sections
- **Modern Theme**: Dark theme optimized for developers

### 📱 **Cross-Platform Compatibility**
- **Multi-Monitor Support**: Seamless adaptation between displays
- **Screen Size Optimization**: From large monitors to small laptops
- **Touch-Friendly**: Works great on tablets and touch devices
- **Godot 4.x Native**: Built specifically for Godot 4

## 🚀 **Quick Start**

### 1. **Installation**
```bash
# Clone the repository
git clone https://github.com/Godot4-Addons/ai_assistant_for_godot.git

# Copy to your project
cp -r ai_assistant_for_godot/addons/ai_coding_assistant your_project/addons/
```

### 2. **Enable Plugin**
1. Open your Godot project
2. Go to **Project Settings > Plugins**
3. Find **AI Coding Assistant** and enable it
4. The AI Assistant dock will appear in the left panel

### 3. **Configure API**
1. Click the **⚙ Settings** button in the AI Assistant dock
2. Select your preferred AI provider (Gemini recommended)
3. Enter your API key
4. Start coding with AI assistance!

## 📚 **Documentation**

### 📖 **User Guides**
- **[Installation Guide](docs/INSTALLATION.md)** - Complete setup instructions
- **[Quick Start Guide](docs/QUICK_START.md)** - Get started in 5 minutes
- **[Enhanced Features](docs/ENHANCED_FEATURES.md)** - Overview of all features
- **[Version Compatibility](docs/VERSION_COMPATIBILITY.md)** - Godot version support

### 🎨 **UI & Design**
- **[Flexible UI Guide](docs/FLEXIBLE_UI_GUIDE.md)** - Responsive design features
- **[Flexible Boxes Guide](docs/FLEXIBLE_BOXES_GUIDE.md)** - UI component details
- **[Enhanced Markdown Guide](docs/ENHANCED_MARKDOWN_GUIDE.md)** - Syntax highlighting
- **[Markdown Examples](docs/MARKDOWN_EXAMPLES.md)** - Visual examples

### 🔧 **Technical Documentation**
- **[Property Fixes](docs/PROPERTY_FIXES_COMPLETE.md)** - Godot 4.x compatibility
- **[Syntax Fixes](docs/SYNTAX_FIXES_COMPLETE.md)** - Code improvements
- **[Upgrade Summary](docs/UPGRADE_SUMMARY.md)** - What's new in v2.0
- **[Final Status Report](docs/FINAL_STATUS_REPORT.md)** - Complete feature list

### 🧪 **Development & Testing**
- **[Testing Guide](docs/TESTING.md)** - How to run tests
- **[Addon Documentation](docs/ADDON_README.md)** - Plugin architecture
- **[Commit History](docs/COMMIT_MESSAGE.md)** - Development changelog

## 🎯 **Core Features**

### **AI-Powered Coding**
- **Code Generation**: Generate functions, classes, and complete scripts
- **Code Explanation**: Understand complex code with AI explanations
- **Code Improvement**: Get suggestions for optimization and best practices
- **Error Debugging**: AI-assisted debugging and error resolution

### **Enhanced User Interface**
- **Responsive Design**: Automatically adapts to screen size
- **Professional Styling**: VS Code-inspired dark theme
- **Flexible Layout**: Resizable chat and code panels
- **Context Menus**: Right-click for quick actions

### **Advanced Markdown Support**
- **Syntax Highlighting**: GDScript, Python, JavaScript, JSON
- **Rich Formatting**: Headers, lists, quotes, links
- **Code Blocks**: Language-labeled with professional styling
- **Real-time Rendering**: See formatting as you type

## 📱 **Screen Size Support**

| Screen Size | Layout | Features |
|-------------|--------|----------|
| **Large (>1000px)** | Expanded | Full features, generous spacing |
| **Medium (600-1000px)** | Balanced | Optimized for productivity |
| **Small (400-600px)** | Compact | Auto-collapse, space efficient |
| **Mobile (<400px)** | Minimal | Essential functions only |

## 🎨 **Visual Examples**

### **Enhanced Markdown Highlighting**
```gdscript
# GDScript with syntax highlighting
func _ready():
    var message = "Hello, AI Assistant!"
    print(message)
```

### **Professional Code Blocks**
- **Language Labels**: Clear indicators for each code block
- **Syntax Colors**: Keywords, strings, comments highlighted
- **Line Numbers**: Optional line numbering for code
- **Copy/Save**: One-click code operations

## 🔧 **API Providers**

### **Gemini (Recommended)**
- **Model**: gemini-2.0-flash
- **Features**: Fast, accurate, cost-effective
- **Setup**: Get API key from Google AI Studio

### **HuggingFace**
- **Models**: Various open-source models
- **Features**: Free tier available
- **Setup**: Get API key from HuggingFace

### **Cohere**
- **Models**: Command series
- **Features**: Enterprise-grade
- **Setup**: Get API key from Cohere

## 🛠️ **Development**

### **Requirements**
- Godot 4.x (4.0 or later)
- Internet connection for AI features
- API key from supported provider

### **Building from Source**
```bash
# Clone repository
git clone https://github.com/Godot4-Addons/ai_assistant_for_godot.git
cd ai_assistant_for_godot

# Run tests
godot --headless --script test/run_all_tests.gd

# Install in your project
cp -r addons/ai_coding_assistant /path/to/your/project/addons/
```

### **Contributing**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new features
5. Submit a pull request

## 📊 **Statistics**

- **🎯 4 AI Providers**: Gemini, HuggingFace, Cohere, Custom
- **🎨 4 Languages**: GDScript, Python, JavaScript, JSON syntax highlighting
- **📱 4 Screen Sizes**: Optimized layouts for all display types
- **🔧 20+ Features**: Comprehensive development assistance
- **📚 15+ Docs**: Complete documentation and guides
- **🧪 25+ Tests**: Thorough quality assurance

## 🤝 **Community**

- **GitHub Issues**: [Report bugs and request features](https://github.com/Godot4-Addons/ai_assistant_for_godot/issues)
- **Discussions**: [Join the community discussion](https://github.com/Godot4-Addons/ai_assistant_for_godot/discussions)
- **Wiki**: [Community-maintained documentation](https://github.com/Godot4-Addons/ai_assistant_for_godot/wiki)

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Godot Engine**: For the amazing game engine
- **AI Providers**: Gemini, HuggingFace, Cohere for AI capabilities
- **Community**: Contributors and users who make this project better
- **VS Code**: Inspiration for the syntax highlighting theme

---

**Made with ❤️ for the Godot community**

*Transform your Godot development experience with professional AI assistance!* 🚀✨
