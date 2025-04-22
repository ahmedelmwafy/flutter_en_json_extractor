# Flutter Localization Extractor

This Dart CLI tool scans your Flutter project's Dart files, extracts string literals, replaces them with localization calls using `.tr()`, and generates a JSON localization file (`en.json`) with the original strings as both keys and values.

## Features

✅ Automatically detects and processes Dart files in your `lib/` directory  
✅ Skips strings in import statements, print/log calls, paths, and already localized strings  
✅ Supports both `localize_and_translate` and `easy_localization` packages  
✅ Automatically inserts the necessary import statement if missing  
✅ Generates a clean, sorted `en.json` localization file  

---

## Installation

You can include this script directly in your Flutter project (e.g., in a `tools/` folder), or install it as a package.

### Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_en_json_extractor: latest version
    
    
    ```bash
    # Run the package after adding it to pubspec.yaml
    dart run flutter_en_json_extractor
    ```