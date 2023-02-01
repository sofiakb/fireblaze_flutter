import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart' as fire;
import 'package:mime/mime.dart';

fire.FirebaseStorage storage = fire.FirebaseStorage.instance;

class FireblazeStorage {
  static Future<fire.Reference> upload(
      {required String destination, required File file}) async {
    fire.Reference storageRef = storage.ref(destination);

    if (destination.contains('/')) {
      List<String> splat = destination.split('/');

      storageRef = storage.ref(splat[0]);

      splat.skip(1).forEach((pathSection) {
        storageRef = storageRef.child(pathSection);
      });
    }

    return (await storageRef.putFile(file,
        fire.SettableMetadata(contentType: lookupMimeType(file.path))))
        .ref;
  }
}
