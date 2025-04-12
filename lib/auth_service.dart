import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Đăng ký
  Future<User?> register(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e; // Ném lỗi lên để xử lý ở tầng trênnn
    } catch (e) {
      throw Exception('Đăng ký thất bạiiii: $e');
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
      throw e; // Ném lỗi lên để xử lý ở tầng trên
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
}