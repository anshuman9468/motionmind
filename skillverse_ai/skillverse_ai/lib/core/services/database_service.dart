import 'package:cloud_firestore/cloud_firestore.dart';

abstract class DatabaseService {
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> getUserProfile(String uid);
}

class FirestoreService implements DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }
}

class MockDatabaseService implements DatabaseService {
  final Map<String, Map<String, dynamic>> _storage = {};

  @override
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    _storage[uid] = data;
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _storage[uid];
  }
}
