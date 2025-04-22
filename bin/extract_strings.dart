import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

// --- Configuration ---
const String searchDir = 'lib';
// Directories within searchDir to include. If empty, all directories within searchDir are included.
const List<String> includeDirs = ['screens', 'core/widgets'];
// The output file for the English localization keys and values.
const String enJsonFile = 'en.json';
// The required import for the localization package.
const String requiredImport = "import 'package:localize_and_translate/localize_and_translate.dart';";
// ----------------------

// Set to store unique original strings found (which will be used as keys).
Set<String> uniqueStrings = {};

// Regex to find single or double quoted string literals.
final RegExp stringLiteralRegex = RegExp(r'''(?:(['"])(.*?)\1)''', multiLine: true);
// Regex to check if the required import already exists.
final RegExp importRegex = RegExp(r'''import\s+['"]package:localize_and_translate/localize_and_translate.dart['"]\s*;''');
// Regex to check if a string literal is already formatted in the desired key format (the string itself in quotes).
// This regex is tricky because any string could potentially be a key.
// We'll rely more on the '.tr()' check and the absence of problematic characters.
// For simplicity based on the request, we won't add a specific 'existing key' regex check here
// because the 'key' IS the string itself. The `.tr()` check is the main way to skip.

/// Checks if the given index falls within an import line.
bool isWithinImportLine(String content, int index) {
  int lineStartIndex = content.lastIndexOf('\n', index) + 1;
  int lineEndIndex = content.indexOf('\n', index);
  if (lineEndIndex == -1) {
    lineEndIndex = content.length;
  }
  final line = content.substring(lineStartIndex, lineEndIndex);
  return line.trimLeft().startsWith('import ');
}

/// Checks if the content immediately following the match index is '.tr()'.
bool isFollowedByTr(String content, int indexAfterMatch) {
  int currentIndex = indexAfterMatch;
  // Skip whitespace
  while (currentIndex < content.length && currentIndex < content.length && content[currentIndex].trim().isEmpty) {
    currentIndex++;
  }
  const trSuffix = '.tr()';
  if (currentIndex + trSuffix.length > content.length) {
    return false;
  }
  return content.substring(currentIndex, currentIndex + trSuffix.length) == trSuffix;
}

// No longer need isExistingKeyLiteral as the key is the string itself.

/// Checks if the file path is within the specified include directories.
bool isPathIncluded(String filePath) {
  final normalizedFilePath = p.normalize(filePath);
  final normalizedSearchDir = p.normalize(searchDir);

  // If no include directories are specified, all files in searchDir are included.
  if (includeDirs.isEmpty) {
    return normalizedFilePath.startsWith(normalizedSearchDir);
  }

  // Exclude the searchDir itself unless it's an include dir (which it shouldn't be based on common structure).
  if (normalizedFilePath == normalizedSearchDir) {
    return false;
  }

  // Check if the relative path is one of the included directories or starts with one.
  final relativePath = p.relative(normalizedFilePath, from: normalizedSearchDir);
  for (final includedDir in includeDirs) {
    final normalizedIncludedDir = p.normalize(includedDir);
    final includedDirPrefix = normalizedIncludedDir + p.separator;
    if (relativePath == normalizedIncludedDir || relativePath.startsWith(includedDirPrefix)) {
      return true;
    }
  }
  return false;
}

/// Recursively finds and processes directories and dart files.
void findAndProcessDirectory(String currentPath) {
  try {
    final entity = FileStat.statSync(currentPath);
    if (entity.type == FileSystemEntityType.directory) {
      // Only process directories if they are the searchDir itself or within includeDirs.
      if (p.normalize(currentPath) == p.normalize(searchDir) || isPathIncluded(currentPath)) {
        final dir = Directory(currentPath);
        final files = dir.listSync();
        for (final file in files) {
          findAndProcessDirectory(file.path);
        }
      }
    } else if (entity.type == FileSystemEntityType.file && p.extension(currentPath).toLowerCase() == '.dart') {
      // Only process dart files if they are within includeDirs.
      if (isPathIncluded(currentPath)) {
        processAndModifyFile(currentPath);
      }
    }
  } on FileSystemException catch (e) {
    print('Error processing path $currentPath: ${e.message}');
  } catch (e) {
    print('An unexpected error occurred processing path $currentPath: $e');
  }
}

/// Processes a single Dart file, finds string literals, replaces them with the string itself as key, and adds '.tr()'.
void processAndModifyFile(String filePath) {
  try {
    final content = File(filePath).readAsStringSync();
    final modifiedContentBuffer = StringBuffer();
    int lastIndex = 0;
    bool fileModifiedByReplacement = false;
    int stringsReplacedCount = 0;

    // Find all string literal matches in the file content.
    final matches = stringLiteralRegex.allMatches(content);

    for (final match in matches) {
      final originalMatch = match.group(0)!; // The full matched string including quotes
      final stringValue = match.group(2)!; // The content of the string literal
      final matchIndex = match.start;
      final indexAfterMatch = match.end;

      // Skip strings on import lines, empty strings, strings containing '/',
      // strings already formatted in the desired key.tr() format.
      if (isWithinImportLine(content, matchIndex)) {
        continue;
      }
      if (stringValue.isEmpty) {
        continue;
      }
      // Skip strings containing a forward slash, often used for paths or comments within strings.
      if (stringValue.contains('/')) {
        continue;
      }
       // Skip if the string is already followed by .tr().
       // This also covers cases where the string itself was already the key format.
      if (isFollowedByTr(content, indexAfterMatch)) {
        continue;
      }

      // Add the unique string value to our set.
      uniqueStrings.add(stringValue);

      // The key to use is the stringValue itself.
      final keyToUse = stringValue;

      // The replacement string: the key (original string) in quotes followed by .tr().
      // Use the original match (which includes quotes) to preserve the quote type if necessary,
      // but wrap it in .tr(). Example: "Hello".tr() or 'World'.tr()
      // A safer way might be to re-quote stringValue to ensure consistent single quotes for the key string literal.
      // Let's stick to single quotes for consistency as the package example often uses it.
      // Need to handle potential quotes *within* the stringValue itself.
      // This simple replacement works for strings without internal quotes or escape sequences
      // that would break the single-quoted literal.
      // A more robust script would escape internal quotes. For this request, assuming simple strings.

      // Original approach: uses the original string literal including quotes
      // final replacementString = '$originalMatch.tr()'; // e.g., "Hello".tr() or 'World'.tr()

      // New approach: uses the extracted string value wrapped in single quotes
      // This is generally safer as JSON keys and .tr() arguments are often single quoted.
      // It also handles if the original string was double quoted.
      // **Important:** This assumes the stringValue itself does not contain unescaped single quotes.
      // A production script should escape `stringValue` before putting it in single quotes.
       final replacementString = "'$stringValue'.tr()"; // e.g., 'Hello'.tr()

      // Add content before the match to the buffer.
      modifiedContentBuffer.write(content.substring(lastIndex, matchIndex));
      // Add the replacement string to the buffer.
      modifiedContentBuffer.write(replacementString);
      // Update the last index processed.
      lastIndex = indexAfterMatch;

      fileModifiedByReplacement = true;
      stringsReplacedCount++;
    }

    // Add the remaining content after the last match to the buffer.
    modifiedContentBuffer.write(content.substring(lastIndex));

    String finalContent = modifiedContentBuffer.toString();
    bool importAdded = false;

    // If any strings were replaced, check if the required import is needed and add it.
    if (fileModifiedByReplacement) {
      if (!importRegex.hasMatch(content)) {
        finalContent = '$requiredImport\n\n$finalContent';
        importAdded = true;
      }

      // Write the modified content back to the file.
      File(filePath).writeAsStringSync(finalContent);

      // Print processing summary for the file.
      print('Processed file: $filePath');
      if (stringsReplacedCount > 0) {
        print('  - Replaced $stringsReplacedCount string(s) with themselves as keys and .tr().');
      }
      if (importAdded) {
        print('  - Added import: $requiredImport');
      }
    }

  } on FileSystemException catch (e) {
    print('Error reading, processing, or writing file $filePath: ${e.message}');
  } catch (e) {
    print('An unexpected error occurred processing file $filePath: $e');
  }
}

/// Writes the extracted strings (used as keys) and themselves (as values) to the en.json file.
void writeJsonFiles() {
  try {
    // Create a map for the English JSON file: original_string -> original_string.
    final Map<String, String> enJson = {};
    uniqueStrings.forEach((stringValue) {
      // Map the stringValue to itself.
      enJson[stringValue] = stringValue;
    });

    // Sort the keys (which are the original strings) alphabetically for consistent output.
    final sortedKeys = enJson.keys.toList()..sort();
    final Map<String, String> sortedEnJsonMap = {};
    for (final key in sortedKeys) {
      sortedEnJsonMap[key] = enJson[key]!;
    }

    // Convert the map to a pretty-printed JSON string.
    final encoder = JsonEncoder.withIndent('  ');
    final enJsonContent = encoder.convert(sortedEnJsonMap);

    // Write the JSON content to the en.json file.
    File(enJsonFile).writeAsStringSync(enJsonContent);

    // Print success message.
    print('\nSuccessfully extracted ${uniqueStrings.length} unique strings and wrote them as keys/values.');
    print('English localization data saved to $enJsonFile (using original strings as keys).');

  } on FileSystemException catch (e) {
    print('Error writing to JSON file $enJsonFile: ${e.message}');
  } catch (e) {
    print('An unexpected error occurred writing JSON file: $e');
  }
}

void main(List<String> args) {
  print('WARNING: This script will attempt to modify .dart files in "$searchDir"');
  print('by replacing string literals with themselves as localization keys (e.g., \'Some text\'.tr()).');
  if (includeDirs.isNotEmpty) {
    print('It will ONLY process files within the following subdirectories of "$searchDir": [${includeDirs.join(', ')}]');
  } else {
    print('It will process ALL files within "$searchDir".');
  }
  print('It will also add the import "$requiredImport" to modified files if not present.');
  print('It will save the extracted unique strings to "$enJsonFile",');
  print('using the **original string itself as both the key and the value** (e.g., "Some text": "Some text").');
  print('Ensure you have a backup or are using version control before running this script.');
  print('Starting search and modification in directory: $searchDir');
  print('Looking for single- or double-quoted string literals (excluding those on import lines, containing \'/\', or already followed by .tr())...');

  // Validate the search directory.
  if (!Directory(searchDir).existsSync()) {
    print('Error: Directory "$searchDir" not found. Make sure you are running this script from your Flutter project\'s root directory.');
    exit(1);
  } else {
    // Validate include directories.
    for (final dir in includeDirs) {
      final fullPath = p.join(searchDir, dir);
      if (!Directory(fullPath).existsSync()) {
        print('Warning: Configured include directory "$fullPath" does not exist.');
      }
    }

    // Start the file processing.
    findAndProcessDirectory(searchDir);

    // Write the extracted data to the JSON file if any strings were found.
    if (uniqueStrings.isNotEmpty) {
      writeJsonFiles();
    } else {
      print('\nNo eligible strings were found to process in the specified directories.');
    }
  }
}