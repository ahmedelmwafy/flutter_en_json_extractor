# Flutter String Localization Automation Script

This script is a Dart-based command-line tool designed to help automate the process of internationalizing your Flutter application using popular localization packages like `localize_and_translate` or `easy_localization`.

It finds hardcoded string literals in your Dart files within a **specified folder** inside `lib`, replaces them with localization keys followed by `.tr()`, and generates an `en.json` file where the original English strings serve as both the keys and the values.

## Features

* Scans `.dart` files within a **single folder** inside the `lib` directory, specified by the user during runtime.
* Identifies single-quoted (`'...'`) and double-quoted (`"..."`) string literals.
* Replaces found strings like `"Hello World"` with `'Hello World'.tr()`.
* **Uses the original string literal content directly as the localization key.**
* Generates or updates `en.json` with entries like `"Hello World": "Hello World"`.
* Adds the correct import statement (`localize_and_translate` or `easy_localization`) to modified files if missing, based on user selection.
* Skips strings on import lines, empty strings, strings containing '/', and strings already followed by `.tr()`.

## Prerequisites

* [Dart SDK](https://dart.dev/get-dart) installed.
* A Flutter project where you want to apply localization.
* You are using either the [`localize_and_translate`](https://pub.dev/packages/localize_and_translate) or [`easy_localization`](https://pub.dev/packages/easy_localization`) package in your project.
* The script file (`your_script_name.dart`) placed in your project directory (e.g., at the root or in a `tool/` folder).

## Installation

1.  Save the provided Dart script code into a file (e.g., `auto_localize.dart`) within your Flutter project directory (e.g., project root, or a `tool/` subdirectory).

## Configuration

Open the script file (`auto_localize.dart`) and modify the constants at the top if needed:

* `searchDir`: The base directory to look for the user-specified folder within (defaults to `'lib'`).
* `enJsonFile`: The name of the output JSON file (defaults to `'en.json'`). This file will be created/updated in the directory where you run the script (usually the project root).

```dart
// --- Configuration ---
const String searchDir = 'lib';
// The output file for the English localization keys and values.
const String enJsonFile = 'en.json';
// ----------------------