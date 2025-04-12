import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Thêm Firebase Storage
import 'package:file_picker/file_picker.dart'; // Thêm file_picker
import 'auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _avatarUrl;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Lấy thông tin người dùng hiện tại
    String? userId = AuthService().getCurrentUser()?.uid;
    if (userId != null) {
      FirebaseFirestore.instance.collection('users').doc(userId).get().then((snapshot) {
        if (snapshot.exists) {
          var userData = snapshot.data() as Map<String, dynamic>;
          _nameController.text = userData['name'] ?? '';
          setState(() {
            _avatarUrl = userData['avatar'] ?? 'https://example.com/default-avatar.png';
          });
        }
      });
    }
  }

  // Hàm chọn ảnh từ thiết bị
  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image, // Chỉ cho phép chọn ảnh
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: ${e.toString()}')),
      );
    }
  }

  // Hàm tải ảnh lên Firebase Storage và lấy URL
  Future<String?> _uploadImageToStorage(File image) async {
    try {
      String? userId = AuthService().getCurrentUser()?.uid;
      if (userId == null) return null;

      // Tạo tham chiếu đến vị trí lưu trữ trên Firebase Storage
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('$userId.jpg');

      // Tải ảnh lên
      await storageRef.putFile(image);

      // Lấy URL của ảnh
      String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải ảnh lên: ${e.toString()}')),
      );
      return null;
    }
  }

  Future<void> _updateProfile() async {
    String? userId = AuthService().getCurrentUser()?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để chỉnh sửa hồ sơ.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? newAvatarUrl = _avatarUrl;
      if (_selectedImage != null) {
        // Tải ảnh lên Firebase Storage nếu người dùng chọn ảnh mới
        newAvatarUrl = await _uploadImageToStorage(_selectedImage!);
        if (newAvatarUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Cập nhật thông tin vào Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'avatar': newAvatarUrl,
      });

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật hồ sơ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Chỉnh Sửa Hồ Sơ',
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
                'Cập nhật thông tin cá nhân',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Hiển thị ảnh đại diện hiện tại hoặc ảnh đã chọn
              CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : _avatarUrl != null
                    ? NetworkImage(_avatarUrl!)
                    : null,
                backgroundColor: Colors.grey[700],
                child: _selectedImage == null && _avatarUrl == null
                    ? const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 50,
                )
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Chọn ảnh đại diện',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tên người dùng',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _updateProfile,
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
                  'Cập Nhật',
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