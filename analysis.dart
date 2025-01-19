import 'dart:convert';
import 'dart:io';

void main() {
  const String inputFilePath = 'output/retry_results.json';
  const String outputFilePath = 'output/merge_order.json';
  const String conflictLogPath = 'output/conflict_details.json';

  // Read the JSON file
  final File inputFile = File(inputFilePath);
  if (!inputFile.existsSync()) {
    print("ERROR: Input file $inputFilePath not found.");
    return;
  }

  final String jsonString = inputFile.readAsStringSync();
  final Map<String, dynamic> jsonData = jsonDecode(jsonString);

  if (!jsonData.containsKey('retry_attempts')) {
    print("ERROR: Missing 'retry_attempts' key in JSON.");
    return;
  }

  List<Map<String, dynamic>> retryAttempts =
      List<Map<String, dynamic>>.from(jsonData['retry_attempts']);

  // Categorization function for Clean Architecture with Riverpod
  String categorizeFile(String filePath) {
    if (filePath.contains('core/config') || filePath.contains('core/utils')) {
      return 'core';
    } else if (filePath.contains('features') ||
        filePath.contains('presentation')) {
      return 'presentation';
    } else if (filePath.contains('data') || filePath.contains('repository')) {
      return 'data';
    } else if (filePath.contains('domain')) {
      return 'domain';
    } else if (filePath.contains('service') ||
        filePath.contains('controller')) {
      return 'service';
    } else if (filePath.contains('state') || filePath.contains('provider')) {
      return 'state_management';
    } else if (filePath.contains('testing') || filePath.contains('test')) {
      return 'testing';
    }
    return 'unknown';
  }

  // Define merge order priority
  List<String> mergePriority = [
    'core',
    'domain',
    'data',
    'service',
    'state_management',
    'presentation',
    'feature',
    'utility',
    'testing',
    'unknown'
  ];
  // Branch categorization and conflict tracking
  Map<String, String> branchCategories = {};
  Map<String, List<String>> branchFiles = {};
  Map<String, Map<String, dynamic>> conflictDetails = {};

  for (var attempt in retryAttempts) {
    if (attempt['status'] != 'FAILED') continue;

    String branchName = attempt['name'];
    List<String> conflictFiles =
        List<String>.from(attempt['conflict_files'].split(','));

    print("DEBUG: Processing branch: $branchName");
    print("DEBUG: Conflicting files for $branchName: $conflictFiles");

    Set<String> categories =
        {}; // A branch might have files from multiple categories

    for (String file in conflictFiles) {
      String category = categorizeFile(file);
      categories.add(category);
      branchFiles.putIfAbsent(branchName, () => []).add(file);
    }

    // Assign the highest-priority category based on predefined order
    for (var category in mergePriority) {
      if (categories.contains(category)) {
        branchCategories[branchName] = category;
        break;
      }
    }

    // Store conflict details per branch
    conflictDetails[branchName] = {
      'category': branchCategories[branchName] ?? 'unknown',
      'conflict_files': conflictFiles
    };
  }

  // Sorting branches into merge order based on Clean Architecture
  Map<String, List<String>> categorizedBranches = {
    'core': [],
    'domain': [],
    'data': [],
    'service': [],
    'state_management': [],
    'presentation': [],
    'feature': [],
    'utility': [],
    'testing': [],
    'unknown': []
  };

  // Categorize branches
  branchCategories.forEach((branch, category) {
    if (categorizedBranches.containsKey(category)) {
      categorizedBranches[category]!.add(branch);
    } else {
      print("WARNING: Unrecognized category for branch: $branch");
      categorizedBranches['unknown']!.add(branch);
    }
  });

  // Generate merge order
  List<String> suggestedMergeOrder = mergePriority
      .expand((category) => categorizedBranches[category]!)
      .toList();

  // Output JSON with merge order
  final outputJson = jsonEncode({'suggested_merge_order': suggestedMergeOrder});
  File(outputFilePath).writeAsStringSync(outputJson);

  // Output conflict details for debugging
  final conflictLogJson = jsonEncode({'conflict_details': conflictDetails});
  File(conflictLogPath).writeAsStringSync(conflictLogJson);

  print("DEBUG: Final merge order: $suggestedMergeOrder");
  print("Suggested merge order saved to $outputFilePath");
  print("Conflict details saved to $conflictLogPath");
}
