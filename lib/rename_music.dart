import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RenameMusic extends StatefulWidget {
  const RenameMusic({super.key});

  @override
  _RenameMusicState createState() => _RenameMusicState();
}

class _RenameMusicState extends State<RenameMusic> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _updateMusicName(String docId, String newName) async {
    if (newName.trim().isEmpty) {
      print('_updateMusicName: Tên bản nhạc trống - docId: $docId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tên bản nhạc không được để trống!")),
      );
      return;
    }

    try {
      final docSnapshot = await _firestore.collection('sheet_music').doc(docId).get();
      if (!docSnapshot.exists) {
        print('_updateMusicName: Document không tồn tại - docId: $docId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bản nhạc không tồn tại!")),
        );
        return;
      }

      print('_updateMusicName: Cập nhật musicName - docId: $docId, newName: $newName');
      await _firestore.collection('sheet_music').doc(docId).update({
        'musicName': newName.trim(),
      });
      print('_updateMusicName: Cập nhật thành công - docId: $docId, newName: $newName');

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã đổi tên thành: $newName")),
      );
    } catch (e) {
      print('_updateMusicName: Lỗi khi cập nhật - docId: $docId, error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi đổi tên: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Vui lòng đăng nhập để đổi tên bản nhạc!",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        backgroundColor: Colors.grey[900],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        title: const Text(
          "Đổi Tên Bản Nhạc",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('sheet_music')
            .where('uploadedBy', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('_StreamBuilder: Lỗi khi lấy danh sách - error: ${snapshot.error}');
            return Center(
              child: Text(
                "Lỗi khi tải danh sách: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Chưa có bản nhạc nào!",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              final currentName = data['musicName'] as String? ?? 'Không có tên';
              final filePath = data['filePath'] as String? ?? '';

              if (!_controllers.containsKey(docId)) {
                _controllers[docId] = TextEditingController(text: currentName);
              }

              return Card(
                color: Colors.black,
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "File: ${filePath.split('/').last.length > 30 ? '${filePath.split('/').last.substring(0, 27)}...' : filePath.split('/').last}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controllers[docId],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tên bản nhạc',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Nhập tên mới',
                          hintStyle: const TextStyle(color: Colors.grey),
                        ),
                        onChanged: (value) {
                          print('_TextField: Cập nhật tên - docId: $docId, newName: $value');
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            final newName = _controllers[docId]!.text;
                            _updateMusicName(docId, newName);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Lưu tên",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}