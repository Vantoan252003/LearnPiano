import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rename_music.dart';

class SheetMusic extends StatefulWidget {
  const SheetMusic({super.key});

  @override
  _UploadSheetMusic createState() => _UploadSheetMusic();
}

class _UploadSheetMusic extends State<SheetMusic> {
  File? _file;
  String? _fileName;
  String? _fileExtension;
  final TextEditingController _nameController = TextEditingController();
  bool _isUploading = false;
  double? _uploadProgress;

  Future<void> _pickFile() async {
    try {
      print('_pickFile: Bắt đầu chọn file');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        print('_pickFile: Người dùng hủy chọn file hoặc không chọn file');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã hủy chọn file")),
        );
        return;
      }

      final platformFile = result.files.single;
      print('_pickFile: File được chọn - name: ${platformFile.name}, path: ${platformFile.path}, bytes: ${platformFile.bytes != null ? "có bytes" : "không có bytes"}, extension: ${platformFile.extension}');

      final extension = platformFile.extension?.toLowerCase();
      if (extension != 'xml' && extension != 'mxl' && extension != 'musicxml') {
        print('_pickFile: File không đúng định dạng - extension: $extension');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng chọn file .xml, .mxl hoặc .musicxml!")),
        );
        return;
      }

      if (platformFile.path != null) {
        setState(() {
          _file = File(platformFile.path!);
          _fileName = platformFile.name;
          _fileExtension = extension;
          _nameController.clear();
          _uploadProgress = null;
        });
        print('_pickFile: Đã lưu file - name: $_fileName, path: ${platformFile.path}, extension: $_fileExtension');
      } else if (platformFile.bytes != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File('${tempDir.path}/${platformFile.name}');
        await tempFile.writeAsBytes(platformFile.bytes!);
        setState(() {
          _file = tempFile;
          _fileName = platformFile.name;
          _fileExtension = extension;
          _nameController.clear();
          _uploadProgress = null;
        });
        print('_pickFile: Đã lưu file tạm - name: $_fileName, path: ${tempFile.path}, extension: $_fileExtension');
      } else {
        print('_pickFile: File không hợp lệ');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File không hợp lệ! Vui lòng chọn lại.")),
        );
        return;
      }
    } catch (e) {
      print('_pickFile: Lỗi khi chọn file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi chọn file: $e")),
      );
    }
  }

  Future<void> _uploadFile() async {
    if (_file == null || _fileName == null || _fileExtension == null) {
      print('_uploadFile: Thiếu file, tên file hoặc đuôi file');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn file trước!")),
      );
      return;
    }

    final musicName = _nameController.text.trim();
    print('_uploadFile: Tên bản nhạc nhập vào - musicName: $musicName, controller: ${_nameController.text}');

    if (musicName.isEmpty) {
      print('_uploadFile: Thiếu tên bản nhạc');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập tên cho bản nhạc!")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('_uploadFile: Người dùng chưa đăng nhập');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để upload!")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Dùng musicName làm tên file mới, giữ đuôi .mxl
      final newFileName = '$musicName.mxl';
      print('_uploadFile: Upload file - storagePath: mxl/$newFileName, musicName: $musicName');
      final storageRef = FirebaseStorage.instance.ref().child('mxl/$newFileName');
      final uploadTask = storageRef.putFile(_file!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      }, onError: (e) {
        print('_uploadFile: Lỗi upload: $e');
        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload thất bại: $e")),
        );
      });

      await uploadTask;
      final downloadURL = await storageRef.getDownloadURL();
      print('_uploadFile: Upload thành công - downloadURL: $downloadURL');

      final docRef = await FirebaseFirestore.instance.collection('sheet_music').add({
        'musicName': musicName,
        'filePath': 'mxl/$newFileName',
        'downloadURL': downloadURL,
        'uploadedBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('_uploadFile: Đã lưu metadata vào sheet_music/${docRef.id}, musicName: $musicName, filePath: mxl/$newFileName');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload thành công: $musicName")),
      );

      setState(() {
        _file = null;
        _fileName = null;
        _fileExtension = null;
        _nameController.clear();
        _uploadProgress = null;
      });
    } catch (e) {
      print('_uploadFile: Lỗi khi lưu Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload thất bại: $e")),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        title: const Text(
          "Upload Sheet Nhạc",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RenameMusic()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _file == null
                        ? const Text(
                            "Chưa chọn file",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          )
                        : Column(
                            children: [
                              Text(
                                "File: ${_fileName!.length > 30 ? '${_fileName!.substring(0, 27)}...' : _fileName}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Tên bản nhạc',
                                  labelStyle: const TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: Colors.grey[800],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  hintText: 'Nhập tên cho bản nhạc',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                ),
                                onChanged: (value) {
                                  print('_TextField: Cập nhật musicName: $value');
                                },
                              ),
                              const SizedBox(height: 20),
                              _fileName!.toLowerCase().endsWith('.jpg') ||
                                      _fileName!.toLowerCase().endsWith('.jpeg') ||
                                      _fileName!.toLowerCase().endsWith('.png')
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _file!,
                                        height: 300,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                            Icons.broken_image,
                                            size: 200,
                                            color: Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.insert_drive_file, size: 200, color: Colors.white),
                            ],
                          ),
                    const SizedBox(height: 20),
                    if (_isUploading && _uploadProgress != null) ...[
                      Text(
                        "Đang upload: ${_uploadProgress!.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _uploadProgress! / 100,
                        backgroundColor: Colors.grey[700],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                      ),
                      const SizedBox(height: 10),
                    ],
                    ElevatedButton(
                      onPressed: () {
                        print('_pickFile: Nút Chọn file được nhấn, _isUploading: $_isUploading');
                        if (!_isUploading) _pickFile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        "Chọn file",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _uploadFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Upload file",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}