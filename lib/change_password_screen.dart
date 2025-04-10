import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOldText = true;
  bool _obscureNewText = true;
  bool _obscureConfirmText = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService().getCurrentUser() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn cần đăng nhập để thay đổi mật khẩu. Chuyển hướng đến màn hình đăng nhập...'),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    });
  }

  // Hàm kiểm tra định dạng mật khẩu
  String? _validatePassword(String password) {
    if (password.length < 10) {
      return 'Mật khẩu phải có ít nhất 10 ký tự (hiện tại: ${password.length} ký tự).';
    }
    int letterCount = password.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    if (letterCount < 5) {
      return 'Mật khẩu phải có ít nhất 5 chữ cái (hiện tại: $letterCount chữ cái).';
    }
    int numberCount = password.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (numberCount < 4) {
      return 'Mật khẩu phải có ít nhất 4 con số (hiện tại: $numberCount con số).';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt (ví dụ: !@#\$%^&*).';
    }
    return null;
  }

  // Hàm thay đổi mật khẩu
  Future<void> _changePassword() async {
    String oldPassword = _oldPasswordController.text.trim();
    String newPassword = _newPasswordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    // Kiểm tra mật khẩu và xác nhận mật khẩu
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp với mật khẩu mới.')),
      );
      return;
    }

    // Kiểm tra định dạng mật khẩu mới
    String? passwordError = _validatePassword(newPassword);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passwordError)),
      );
      return;
    }

    // Kiểm tra kết nối mạng
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có kết nối mạng. Vui lòng kiểm tra kết nối Wi-Fi hoặc dữ liệu di động và thử lại.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      User? user = AuthService().getCurrentUser();
      if (user != null) {
        // Xác thực lại người dùng bằng mật khẩu cũ
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: oldPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // Nếu xác thực thành công, tiến hành thay đổi mật khẩu
        await user.updatePassword(newPassword).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Yêu cầu đã hết thời gian. Kết nối mạng có thể không ổn định. Vui lòng thử lại sau.');
          },
        );
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thay đổi mật khẩu thành công! Bạn có thể sử dụng mật khẩu mới để đăng nhập.'),
            duration: const Duration(seconds: 5), // Hiển thị lâu hơn để người dùng đọc
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Không tìm thấy người dùng. Vui lòng đăng nhập lại để tiếp tục.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phiên đăng nhập đã hết hạn. Bạn sẽ được chuyển hướng đến màn hình đăng nhập để tiếp tục.'),
            duration: Duration(seconds: 5),
          ),
        );
        await AuthService().logout();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      } else if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu cũ không đúng. Vui lòng kiểm tra và nhập lại.')),
        );
      } else {
        String errorMessage = _getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi không xác định: ${e.toString()}. Vui lòng thử lại sau.')),
      );
    }
  }

  // Hàm xử lý lỗi
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.';
      default:
        return 'Thay đổi mật khẩu thất bại: ${e.message}. Vui lòng thử lại hoặc liên hệ hỗ trợ.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Thay Đổi Mật Khẩu',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Nhập mật khẩu cũ và mới',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _oldPasswordController,
                style: const TextStyle(color: Colors.white),
                obscureText: _obscureOldText,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu cũ',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureOldText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureOldText = !_obscureOldText;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _newPasswordController,
                style: const TextStyle(color: Colors.white),
                obscureText: _obscureNewText,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewText = !_obscureNewText;
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
                  labelText: 'Xác nhận mật khẩu mới',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Thay Đổi Mật Khẩu',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}