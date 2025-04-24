import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'music_viewer.dart';

class PlaySheet extends StatefulWidget {
  const PlaySheet({super.key});

  @override
  State<PlaySheet> createState() => _PlaySheetState();
}

class _PlaySheetState extends State<PlaySheet> {
  Future<List<Map<String, dynamic>>> fetchMusicFiles() async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('mxl');
      final listResult = await storageRef.listAll();
      List<Map<String, dynamic>> files = [];
      for (var item in listResult.items) {
        if (item.name.toLowerCase().endsWith('.mxl')) {
          files.add({
            'name': item.name,
            'fullPath': item.fullPath,
          });
        }
      }
      return files;
    } catch (e) {
      print('Error fetching music files: $e');
      throw Exception('Failed to fetch music files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Phát Sheet Nhạc',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchMusicFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueGrey));
          } else if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không tìm thấy file sheet nhạc.', style: TextStyle(color: Colors.white)));
          } else {
            final files = snapshot.data!;
            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  title: Text(file['name'], style: const TextStyle(color: Colors.white)),
                  tileColor: Colors.black.withOpacity(0.3),
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