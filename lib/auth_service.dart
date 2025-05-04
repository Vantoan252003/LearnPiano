import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() {
    _firestore.settings = const Settings(persistenceEnabled: true);
  }

  Future<User?> register(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();
      print('Registering user: ${userCredential.user?.uid}');
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email,
        'ear_training_high_score': 0,
        'piano_challenge_high_score': 0,
      });
      print('User document created for UID: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during registration: $e');
      rethrow;
    } catch (e) {
      print('Error during registration: $e');
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Logged in user: ${userCredential.user?.uid}');
      await _ensureUserDocument(userCredential.user?.uid);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during login: $e');
      rethrow;
    } catch (e) {
      print('Error during login: $e');
      throw Exception('Đăng nhập thất bại: $e');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    print('User logged out');
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.reload();
      print('Display name updated to: $displayName');
    } catch (e) {
      print('Error updating display name: $e');
      throw Exception('Cập nhật tên thất bại: $e');
    }
  }

  Future<void> updatePhotoURL(File image) async {
    try {
      String userId = _auth.currentUser!.uid;
      Reference ref = _storage.ref().child('user_photos/$userId/profile.jpg');
      await ref.putFile(image);
      String photoURL = await ref.getDownloadURL();
      await _auth.currentUser?.updatePhotoURL(photoURL);
      await _auth.currentUser?.reload();
      print('Photo URL updated for UID: $userId');
    } catch (e) {
      print('Error updating photo URL: $e');
      throw Exception('Cập nhật ảnh đại diện thất bại: $e');
    }
  }

  Future<void> _ensureUserDocument(String? userId) async {
    if (userId == null) {
      print('Cannot ensure user document: userId is null');
      return;
    }
    DocumentReference userDoc = _firestore.collection('users').doc(userId);
    DocumentSnapshot snapshot = await userDoc.get();
    if (!snapshot.exists) {
      print('Creating user document for UID: $userId');
      await userDoc.set({
        'email': _auth.currentUser?.email ?? '',
        'ear_training_high_score': 0,
        'piano_challenge_high_score': 0,
      });
      print('User document created for UID: $userId');
    } else {
      print('User document already exists for UID: $userId');
    }
  }

  Future<void> updateHighScore(String game, int score) async {
    try {
      if (_auth.currentUser == null) {
        print('Cannot update high score: user is not logged in');
        throw Exception('Người dùng chưa đăng nhập');
      }
      String userId = _auth.currentUser!.uid;
      print('Updating high score for UID: $userId, game: $game, score: $score');
      await _ensureUserDocument(userId);
      DocumentReference userDoc = _firestore.collection('users').doc(userId);
      DocumentSnapshot snapshot = await userDoc.get();
      int currentHighScore = snapshot.get('${game}_high_score') ?? 0;
      print('Current high score for $game: $currentHighScore');
      if (score > currentHighScore) {
        await userDoc.update({'${game}_high_score': score});
        print('High score updated for $game to: $score');
      } else {
        print('Score $score is not higher than current high score $currentHighScore, skipping update');
      }
    } catch (e) {
      print('Error updating high score: $e');
      throw Exception('Lưu điểm số thất bại: $e');
    }
  }

  Future<int> getHighScore(String game) async {
    try {
      if (_auth.currentUser == null) {
        print('Cannot get high score: user is not logged in');
        throw Exception('Người dùng chưa đăng nhập');
      }
      String userId = _auth.currentUser!.uid;
      print('Getting high score for UID: $userId, game: $game');
      await _ensureUserDocument(userId);
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(userId).get();
      int highScore = snapshot.get('${game}_high_score') ?? 0;
      print('High score for $game: $highScore');
      return highScore;
    } catch (e) {
      print('Error getting high score: $e');
      throw Exception('Lấy điểm số thất bại: $e');
    }
  }
}