# ✨ Little Star App

<!-- 在這裡放一張 App 的 Banner 或主要截圖 -->
<!-- ![App Screenshot](path/to/screenshot.png) -->

[![Flutter](https://img.shields.io/badge/Flutter-3.7.0+-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
<!-- [![Build Status](...)]() -->

> *"Twinkle, twinkle, little star, how I wonder what you are..."*

**Little Star App** is a magical AI playground designed to bring the power of Large Language Models (LLMs) directly to your device. Powered by [Twinkle AI](https://huggingface.co/twinkle-ai) and the robust [llama.cpp](https://github.com/ggerganov/llama.cpp) engine, this app lets you explore, download, and chat with AI models completely offline.

## 🌟 Key Features

- **🚀 On-Device Inference**: Run GGUF models locally with privacy and speed using `llama.cpp`.
- **💬 AI Chat**: Interact with LLMs through a user-friendly chat interface.
- **📥 Model Manager**: Integrated browser to discover and download GGUF models from Hugging Face.
- **⚡ Performance Testing**: "Completion Mode" to test model raw performance and generation speed.
- **📱 Cross-Platform**: Built with Flutter for Android, iOS, and Desktop (WIP).

## 📸 Screenshots

| Home & Models | Chat Interface | Model Completion |
|:---:|:---:|:---:|
| <!-- ![Home](path1) --> | <!-- ![Chat](path2) --> | <!-- ![Completion](path3) --> |
| Browse & Manage | Chat with AI | Test Performance |

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **Inference Engine**: [llama.cpp](https://github.com/ggerganov/llama.cpp) (via FFI)
- **Local Storage**: [Hive](https://pub.dev/packages/hive)
- **Networking**: [Dio](https://pub.dev/packages/dio)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.7.0 or later)
- C++ Compiler (CMake, GCC/Clang) for building native libraries.
- Android NDK (for Android build) / Xcode (for iOS build).

### Installation

1. **Clone the repository** (including submodules):
   git clone --recursive https://github.com/your-org/little-star-app.git
   cd little-star-app
   2. **Install dependencies**:
   
   flutter pub get
   3. **Build & Run**:
   <!-- 這裡根據您的實際編譯流程填寫，是否需要先跑 script? -->
   flutter run
   ## 📚 Documentation

Check out our development notes for deep dives into the implementation:
- [FFI Integration Guide](docs/develop_notes/pre_alpha.1-00_ffi_integration.md)
- [Android Integration](docs/develop_notes/pre_alpha.1-10_android_llama.cpp_integration.md)
- [iOS Integration](docs/develop_notes/pre_alpha.1-20_ios_llama.cpp_integration.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feat/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: add some amazing feature'`)
4. Push to the Branch (`git push origin feat/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## 🙏 Acknowledgments

- [llama.cpp](https://github.com/ggerganov/llama.cpp) for the incredible inference engine.
- [Hugging Face](https://huggingface.co/) for the model ecosystem.