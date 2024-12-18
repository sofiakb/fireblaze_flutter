import 'package:firebase_storage/firebase_storage.dart' as fire;
import 'package:flutter/cupertino.dart';
import 'package:mime/mime.dart';
import 'package:universal_io/io.dart';

class FireblazeStorage {
  final fire.FirebaseStorage _storage;

  FireblazeStorage({fire.FirebaseStorage? storage})
      : _storage = storage ?? fire.FirebaseStorage.instance;

  Future<fire.Reference> upload({
    required String destination,
    required File file,
  }) async {
    try {
      // Déterminer le type MIME
      final contentType = lookupMimeType(file.path);
      if (contentType == null) {
        throw Exception("Impossible de déterminer le type MIME du fichier.");
      }

      // Construire la référence à partir du chemin de destination
      final storageRef = _storage.ref(destination);

      // Mettre en ligne le fichier
      final uploadTask = await storageRef.putFile(
        file,
        fire.SettableMetadata(contentType: contentType),
      );

      // Retourner la référence du fichier téléchargé
      return uploadTask.ref;
    } on fire.FirebaseException catch (e) {
      // Gestion des erreurs Firebase
      debugPrint('Erreur Firebase lors du téléchargement : ${e.message}');
      rethrow;
    } catch (e) {
      // Gestion des autres erreurs
      debugPrint('Erreur inattendue : $e');
      rethrow;
    }
  }
}
