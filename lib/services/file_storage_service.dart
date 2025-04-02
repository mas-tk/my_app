// lib/services/file_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  // Singleton pattern
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();

  // Get the application documents directory path
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get a file from the documents directory
  Future<File> _localFile(String fileName) async {
    final path = await _localPath;
    return File('$path/$fileName');
  }

  // Read JSON file from assets and return decoded data
  Future<dynamic> readJsonAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      return json.decode(jsonString);
    } catch (e) {
      print('Error reading JSON asset $assetPath: $e');
      return null;
    }
  }

  // Check if local file exists, if not, create it from assets
  Future<bool> ensureLocalJsonFileExists(
    String fileName,
    String assetPath,
  ) async {
    try {
      final file = await _localFile(fileName);

      if (await file.exists()) {
        return true;
      }

      // If local file doesn't exist, copy from assets
      final jsonData = await readJsonAsset(assetPath);
      if (jsonData != null) {
        await writeJsonToFile(fileName, jsonData);
        return true;
      }

      return false;
    } catch (e) {
      print('Error ensuring local JSON file exists: $e');
      return false;
    }
  }

  // Read JSON file from local storage
  Future<dynamic> readJsonFromFile(String fileName) async {
    try {
      final file = await _localFile(fileName);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return json.decode(jsonString);
      }

      return null;
    } catch (e) {
      print('Error reading JSON from file $fileName: $e');
      return null;
    }
  }

  // Write JSON data to local file
  Future<bool> writeJsonToFile(String fileName, dynamic jsonData) async {
    try {
      final file = await _localFile(fileName);

      // Encode JSON data with proper formatting (indentation)
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Write to file
      await file.writeAsString(jsonString);

      print('Successfully wrote JSON data to $fileName');
      return true;
    } catch (e) {
      print('Error writing JSON to file $fileName: $e');
      return false;
    }
  }

  // Copy a JSON file from assets to local storage if it doesn't exist
  Future<void> copyJsonFromAssetsIfNeeded(
    String fileName,
    String assetPath,
  ) async {
    try {
      final file = await _localFile(fileName);

      if (!await file.exists()) {
        // Read from assets
        final jsonData = await readJsonAsset(assetPath);

        if (jsonData != null) {
          // Write to local file
          await writeJsonToFile(fileName, jsonData);
          print('Copied $assetPath to local storage as $fileName');
        }
      }
    } catch (e) {
      print('Error copying JSON from assets: $e');
    }
  }

  // Update a specific file with new data
  Future<bool> updateJsonFile(String fileName, dynamic newData) async {
    try {
      return await writeJsonToFile(fileName, newData);
    } catch (e) {
      print('Error updating JSON file $fileName: $e');
      return false;
    }
  }
}
