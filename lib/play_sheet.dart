import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'music_viewer.dart';
import 'sheet_music.dart';

class PlaySheet extends StatefulWidget {
  const PlaySheet({super.key});

  @override
  State<PlaySheet> createState() => _PlaySheetState();
}

class _PlaySheetState extends State<PlaySheet> {
  Future<List<Map<String, dynamic>>> fetchMusicFiles() async {
    final storageRef = FirebaseStorage.instance.ref().child('mxl');
    final listResult = await storageRef.listAll();
    List<Map<String, dynamic>> files = [];

    for (var item in listResult.items) {
      if (item.name.toLowerCase().endsWith('.mxl')) {
        // Get thumbnail URL if it exists (named same as MXL but with .png or .jpg extension)
        String thumbnailUrl = '';
        try {
          final pngRef = FirebaseStorage.instance.ref().child(
            'thumbnails/${item.name.replaceAll('.mxl', '.png')}',
          );
          thumbnailUrl = await pngRef.getDownloadURL();
        } catch (e) {
          // If PNG not found, try JPG
          try {
            final jpgRef = FirebaseStorage.instance.ref().child(
              'thumbnails/${item.name.replaceAll('.mxl', '.jpg')}',
            );
            thumbnailUrl = await jpgRef.getDownloadURL();
          } catch (e) {
            // No thumbnail found, leave as empty string
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        title: const Text(
          'Thư viện Sheet Nhạc',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 28,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.upload_file,
              color: Colors.orangeAccent,
              size: 30,
            ),
            tooltip: 'Upload sheet nhạc',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SheetMusic()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchMusicFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => setState(() {}),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_music, color: Colors.grey[700], size: 64),
                  const SizedBox(height: 18),
                  const Text(
                    'Chưa có sheet nhạc nào. Hãy upload sheet nhạc đầu tiên!',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    label: const Text(
                      'Upload sheet nhạc',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SheetMusic(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          } else {
            final files = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.grey[850],
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child:
                              file['thumbnailUrl'].isNotEmpty
                                  ? Image.network(
                                    file['thumbnailUrl'],
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 160,
                                              color: Colors.grey[800],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.music_note,
                                                  size: 48,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 160,
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    height: 160,
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
                        Padding(
                          padding: const EdgeInsets.all(18.0),
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Nhấn để xem & phát sheet nhạc',
                                      style: TextStyle(
                                        color: Colors.orange[200],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_right,
                                color: Colors.white70,
                                size: 32,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text(
          'Upload sheet nhạc',
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SheetMusic()),
          );
        },
      ),
    );
  }
}
