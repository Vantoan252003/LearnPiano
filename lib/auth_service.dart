import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Đăng ký với email, mật khẩu và tên
  Future<User?> register(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Cập nhật tên người dùng
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload(); // Cập nhật thông tin user
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  // Đăng nhập
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      throw Exception('Đăng nhập thất bại: $e');
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Lấy user hiện tại
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Cập nhật tên người dùng
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Cập nhật tên thất bại: $e');
    }
  }

  // Cập nhật ảnh đại diện
  Future<void> updatePhotoURL(File image) async {
    try {
      String userId = _auth.currentUser!.uid;
      Reference ref = _storage.ref().child('user_photos/$userId/profile.jpg');
      await ref.putFile(image);
      String photoURL = await ref.getDownloadURL();
      await _auth.currentUser?.updatePhotoURL(photoURL);
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Cập nhật ảnh đại diện thất bại: $e');
    }
  }
}