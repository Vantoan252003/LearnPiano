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
          // Get thumbnail URL if it exists (named same as MXL but with .png or .jpg extension)
          String thumbnailUrl = '';
          try {
            final thumbnailRef = FirebaseStorage.instance.ref().child(
              'thumbnails/${item.name.replaceAll('.mxl', '.png')}',
            );
            thumbnailUrl = await thumbnailRef.getDownloadURL();
          } catch (e) {
            // If PNG not found, try JPG
            try {
              final thumbnailRef = FirebaseStorage.instance.ref().child(
                'thumbnails/${item.name.replaceAll('.mxl', '.jpg')}',
              );
              thumbnailUrl = await thumbnailRef.getDownloadURL();
            } catch (e) {
              // No thumbnail found, will use default
              print('No thumbnail found for ${item.name}');
            }
          }

          // Remove .mxl extension for display name
          String displayName = item.name.replaceAll('.mxl', '');
          // Format the display name nicely (capitalize first letter of each word)
          displayName = displayName
              .split('_')
              .map(
                (word) =>
                    word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1)}'
                        : '',
              )
              .join(' ');

          files.add({
            'name': item.name,
            'displayName': displayName,
            'fullPath': item.fullPath,
            'thumbnailUrl': thumbnailUrl,
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
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueGrey),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lỗi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note_outlined, color: Colors.grey, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Không tìm thấy file sheet nhạc.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          } else {
            final files = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.black.withOpacity(0.5),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MusicViewer(
                                filePath: file['fullPath'],
                                fileName: file['displayName'],
                              ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sheet music thumbnail or placeholder
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child:
                              file['thumbnailUrl'].isNotEmpty
                                  ? Image.network(
                                    file['thumbnailUrl'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 150,
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: Icon(
                                            Icons.music_note,
                                            size: 48,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      );
                                    },
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 150,
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    height: 150,
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.music_note,
                                        size: 48,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                        ),

                        // Music title and details
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file['displayName'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nhấn để phát',
                                      style: TextStyle(
                                        color: Colors.blue[200],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_right,
                                color: Colors.white70,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
