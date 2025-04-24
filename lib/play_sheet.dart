import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'music_viewer.dart';

class PlaySheet extends StatefulWidget {
  const PlaySheet({super.key});

  @override
  State<PlaySheet> createState() => _PlaySheetState();
}

class _PlaySheetState extends State<PlaySheet> {
  // Lấy danh sách file từ Firebase Storage (lọc file .mxl)
  Future<List<Map<String, dynamic>>> fetchMusicFiles() async {
    final storageRef = FirebaseStorage.instance.ref().child('mxl');
    final listResult = await storageRef.listAll();
    List<Map<String, dynamic>> files = [];
    for (var item in listResult.items) {
      if (item.name.endsWith('.mxl')) {
        files.add({
          'name': item.name,
          'fullPath': item.fullPath,
        });
      }
    }
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phát Sheet Nhạc'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchMusicFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No music files found.'));
          } else {
            final files = snapshot.data!;
            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  title: Text(file['name']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MusicViewer(
                          filePath: file['fullPath'],
                          fileName: file['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}