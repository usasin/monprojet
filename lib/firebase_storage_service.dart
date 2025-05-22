import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService._privateConstructor();
  static final FirebaseStorageService instance = FirebaseStorageService._privateConstructor();

  Future<String> uploadFile(File file, String filePath) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('File uploaded successfully: $downloadUrl');
      return downloadUrl; // Retourner l'URL pour une utilisation ultérieure
    } catch (e) {
      print('Error uploading file: $e');
      return ''; // Retourner une chaîne vide en cas d'erreur
    }
  }

  Future<String> getDownloadUrl(String filePath) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child(filePath);
      String downloadUrl = await ref.getDownloadURL();
      print('File download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error getting download URL: $e');
      return '';
    }
  }
}

