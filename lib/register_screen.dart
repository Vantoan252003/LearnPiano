import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _obscureConfirmText = true;

  // Hàm kiểm tra định dạng email
  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  // Hàm kiểm tra định dạng mật khẩu
  String? _validatePassword(String password) {
    if (password.length < 10) {
      return 'Mật khẩu phải có ít nhất 10 ký tự';
    }
    int letterCount = password.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    if (letterCount < 5) {
      return 'Mật khẩu phải có ít nhất 5 chữ cái';
    }
    int numberCount = password.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (numberCount < 4) {
      return 'Mật khẩu phải có ít nhất 4 con số';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt';
    }
    return null;
  }

  // Hàm kiểm tra tên
  String? _validateName(String name) {
    if (name.isEmpty) {
      return 'Vui lòng nhập tên';
    }
    if (name.length < 2) {
      return 'Tên phải có ít nhất 2 ký tự';
    }
    return null;
  }

  void _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String name = _nameController.text.trim();

    // Kiểm tra từng trường
    String? emailError = _validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError), backgroundColor: Colors.red),
      );
      return;
    }

    String? nameError = _validateName(name);
    if (nameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nameError), backgroundColor: Colors.red),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu xác nhận không khớp'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? passwordError = _validatePassword(password);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passwordError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      User? user = await _auth.register(email, password, name);
      setState(() => _isLoading = false);

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String errorMessage = _getErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email đã được sử dụng. Vui lòng dùng email khác.';
      case 'invalid-email':
        return 'Email không hợp lệ. Vui lòng kiểm tra lại.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng thử mật khẩu khác.';
      default:
        return 'Đăng ký thất bại: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Đăng Ký',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Tên',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _confirmPasswordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: _obscureConfirmText,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmText = !_obscureConfirmText;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.blueGrey)
                    : ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Đăng Ký',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Đã có tài khoản? Đăng nhập',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}