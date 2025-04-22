import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

// --- Configuration ---
const String searchDir = 'lib';
// Changed the output file path to the desired location
const String enJsonFile = 'assets/lang/en.json';
// ----------------------

// Variables to be set based on user input
late String requiredImport;
late RegExp importRegex;
// Changed to a list to hold multiple target directory paths
late List<String> targetDirectoryPaths;

// Set to store unique original strings found (which will be used as keys).
Set<String> uniqueStrings = {};

// Regex to find single or double quoted string literals.
final RegExp stringLiteralRegex = RegExp(r'''(?:(['"])(.*?)\1)''', multiLine: true);

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

/// Checks if the content immediately following the match index is the appropriate localization suffix.
/// The suffix is determined by the chosen package (.tr() for both currently).
bool isFollowedByLocalizationSuffix(String content, int indexAfterMatch) {
  int currentIndex = indexAfterMatch;
  // Skip whitespace
  while (currentIndex < content.length && content[currentIndex].trim().isEmpty) {
    currentIndex++;
  }

  // Both packages commonly use .tr()
  const suffix = '.tr()';
   if (currentIndex + suffix.length > content.length) {
    return false;
  }
  return content.substring(currentIndex, currentIndex + suffix.length) == suffix;
}

/// Checks if the string literal at matchIndex is within a print() or log() call.
bool isWithinPrintOrLog(String content, int matchIndex) {
  int currentIndex = matchIndex - 1;

  // Skip backward over whitespace before the string literal
  while (currentIndex >= 0 && content[currentIndex].trim().isEmpty) {
    currentIndex--;
  }

  // Check if the character before the whitespace is '('
  if (currentIndex >= 0 && content[currentIndex] == '(') {
    // Found a potential opening parenthesis, now look backward for print or log
    currentIndex--; // Move before the '('

    // Skip backward over whitespace before the '('
     while (currentIndex >= 0 && content[currentIndex].trim().isEmpty) {
      currentIndex--;
    }

    // Now check if the preceding characters are 'print' or 'log'
    // Need to check enough characters backward. 'print' is 5, 'log' is 3.
    // Check for 'print' first (longer keyword)
    if (currentIndex >= 4) { // Need at least 5 characters to check for 'print' including the current index
      final possibleKeyword = content.substring(currentIndex - 4, currentIndex + 1);
      if (possibleKeyword == 'print') {
        // Also check the character *before* 'print' to ensure it's not part of another word (e.g., Myprint)
        if (currentIndex - 5 < 0 || !RegExp(r'\w').hasMatch(content[currentIndex - 5])) {
             return true; // Matched print()
        }
      }
    }
     // Check for 'log'
     if (currentIndex >= 2) { // Need at least 3 characters to check for 'log' including the current index
      final possibleKeyword = content.substring(currentIndex - 2, currentIndex + 1);
       if (possibleKeyword == 'log') {
         // Also check the character *before* 'log' to ensure it's not part of another word (e.g., Mylog)
        if (currentIndex - 3 < 0 || !RegExp(r'\w').hasMatch(content[currentIndex - 3])) {
             return true; // Matched log()
        }
       }
    }
  }

  return false;
}


/// Recursively finds and processes directories and dart files starting from a given path.
void findAndProcessDirectory(String currentPath) {
  try {
    final entity = FileStat.statSync(currentPath);
    if (entity.type == FileSystemEntityType.directory) {
       final dir = Directory(currentPath);
       final files = dir.listSync();
       for (final file in files) {
         // Recurse into subdirectories
         findAndProcessDirectory(file.path);
       }
    } else if (entity.type == FileSystemEntityType.file && p.extension(currentPath).toLowerCase() == '.dart') {
      // Process dart files encountered
       processAndModifyFile(currentPath);
    }
  } on FileSystemException catch (e) {
    print('Error processing path $currentPath: ${e.message}');
  } catch (e) {
    print('An unexpected error occurred processing path $currentPath: $e');
  }
}

/// Processes a single Dart file, finds string literals, replaces them with the string itself as key, and adds '.tr()'.
/// Skips strings based on defined conditions (imports, print/log, etc.).
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

      // --- Skip conditions ---
      // Skip strings on import lines
      if (isWithinImportLine(content, matchIndex)) {
        continue;
      }
      // Skip empty strings
      if (stringValue.isEmpty) {
        continue;
      }
      // Skip strings containing a forward slash (often used for paths or comments within strings).
      if (stringValue.contains('/')) {
        continue;
      }
       // Skip if the string is already followed by the localization suffix (.tr()).
       // This also covers cases where the string itself was already the key format followed by .tr().
      if (isFollowedByLocalizationSuffix(content, indexAfterMatch)) {
        continue;
      }
      // --- New skip condition ---
      // Skip strings within print() or log() calls.
      // If skipped, write the original content segment and move to the next match.
      if (isWithinPrintOrLog(content, matchIndex)) {
        // Optional debug log:
        // print('Skipping string in print/log: "$stringValue" at $filePath:${content.substring(0, matchIndex).split('\n').length}');
        modifiedContentBuffer.write(content.substring(lastIndex, indexAfterMatch)); // Write the original string as is
        lastIndex = indexAfterMatch;
        continue; // Skip adding to uniqueStrings and replacing with .tr()
      }
      // --- End skip conditions ---


      // If we reached here, the string is eligible for processing/translation.
      // Add the unique string value to our set.
      uniqueStrings.add(stringValue);

      // The key to use is the stringValue itself.
      // In a production script, you might want a more robust key generation strategy,
      // but the user requested the original string itself as the key.

      // The replacement string: the key (original string) in quotes followed by .tr().
      // Use the extracted string value wrapped in single quotes.
      // **Important:** This assumes the stringValue itself does not contain unescaped single quotes.
      // A production script should escape `stringValue` before putting it in single quotes.
       final replacementString = "'$stringValue'.tr();"; // Added semicolon as is common after .tr() call

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
    } else {
        // Optional log if a file was processed but no eligible strings were found for replacement
        // print('File processed, no eligible strings found for replacement: $filePath');
    }

  } on FileSystemException catch (e) {
    print('Error reading, processing, or writing file $filePath: ${e.message}');
  } catch (e) {
    print('An unexpected error occurred processing file $filePath: $e');
  }
}

/// Writes the extracted strings (used as keys) and themselves (as values) to the en.json file.
/// Creates the target directory if it doesn't exist.
void writeJsonFiles() {
  try {
    // Ensure the target directory exists before writing the file
    final outputDir = Directory(p.dirname(enJsonFile));
    if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
        print('Created directory: ${outputDir.path}');
    }

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
  print('Flutter Localization Script');
  print('---------------------------');

  // Ask user for package choice
  String? packageChoice;
  while (packageChoice == null) {
    stdout.writeln('Which localization package are you using?');
    stdout.writeln('1. localize_and_translate');
    stdout.writeln('2. easy_localization');
    stdout.write('Enter number (1 or 2): ');

    final input = stdin.readLineSync();
    if (input == '1') {
      requiredImport = "import 'package:localize_and_translate/localize_and_translate.dart';";
      packageChoice = input;
    } else if (input == '2') {
      requiredImport = "import 'package:easy_localization/easy_localization.dart';";
      packageChoice = input;
    } else {
      print('Invalid input. Please enter 1 or 2.');
    }
  }

  // Create the import regex based on the chosen import string
  // Escape any special regex characters in the import string
  final escapedRequiredImport = RegExp.escape(requiredImport);
  importRegex = RegExp(r'\s*' + escapedRequiredImport);

  // Ask user for the target directories
  List<String>? userFolderNames;
  List<String> validatedDirectoryPaths = []; // Temporary list to store validated paths

  while (userFolderNames == null || userFolderNames.isEmpty) {
    stdout.writeln('\nEnter the names of the folders within "$searchDir" to process, separated by commas');
    stdout.write('(e.g., \'screens, components, widgets\'): ');
    final input = stdin.readLineSync()?.trim();

    if (input != null && input.isNotEmpty) {
      final folderNames = input.split(',').map((name) => name.trim()).where((name) => name.isNotEmpty).toList();

      if (folderNames.isEmpty) {
         print('Invalid input. Please enter at least one folder name.');
         continue;
      }

      validatedDirectoryPaths.clear(); // Clear for a new attempt
      bool allValid = true;

      for (final folderName in folderNames) {
         final currentPath = p.join(searchDir, folderName);
         final targetDirEntity = Directory(currentPath);
         if (targetDirEntity.existsSync()) {
             validatedDirectoryPaths.add(currentPath);
         } else {
            print('Error: Directory "$currentPath" not found within "$searchDir". Please check the folder names.');
            allValid = false;
            break; // Stop validation on first error
         }
      }

      if (allValid) {
         targetDirectoryPaths = validatedDirectoryPaths; // Assign the list of valid paths
         userFolderNames = folderNames; // Use for printing summary
      }

    } else {
      print('Invalid input. Please enter folder names.');
    }
  }

  // --- Warnings and Start Message ---
   print('\nWARNING: This script will attempt to modify .dart files within the following directories:');
   for (final path in targetDirectoryPaths) {
       print('  - "$path"');
   }
  print('by replacing string literals with themselves as localization keys (e.g., \'Some text\'.tr()).');
  print('It will also add the import "$requiredImport" to modified files if not present.');
  print('It will save the extracted unique strings to "$enJsonFile",');
  print('using the **original string itself as both the key and the value** (e.g., "Some text": "Some text").');
  print('Strings within print() or log() calls, on import lines, containing \'/\', or already followed by .tr() will be skipped.');
  print('Ensure you have a backup or are using version control before running this script.');
  print('Starting search and modification in the specified directories...');
  // --- End Warnings and Start Message ---


  // Validate the base search directory exists
   if (!Directory(searchDir).existsSync()) {
    print('Error: Base search directory "$searchDir" not found. Make sure you are running this script from your Flutter project\'s root directory.');
    exit(1);
  }

  // Start the file processing from the target directories specified by the user.
  for (final dirPath in targetDirectoryPaths) {
      findAndProcessDirectory(dirPath);
  }

  // Write the extracted data to the JSON file if any strings were found.
  if (uniqueStrings.isNotEmpty) {
    writeJsonFiles();
  } else {
    print('\nNo eligible strings were found to process in the specified directories.');
  }
}