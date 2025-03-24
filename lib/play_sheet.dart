import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class PlaySheet extends StatefulWidget {
  const PlaySheet({super.key});
  @override
  State<PlaySheet> createState() => _PlaySheetState();
}

class _PlaySheetState extends State<PlaySheet> {
  String? selectedSong; // Lưu fullPath của file được chọn
  xml.XmlDocument? musicXmlDocument; // Lưu dữ liệu XML đã phân tích

  // Hàm lấy danh sách file từ Firebase Storage
  Future<List<Map<String, dynamic>>> fetchMusicFiles() async {
    final storageRef = FirebaseStorage.instance.ref().child('mxl');
    final listResult = await storageRef.listAll();
    List<Map<String, dynamic>> files = [];
    for (var item in listResult.items) {
      final metadata = await item.getMetadata();
      files.add({
        'name': item.name,
        'fullPath': item.fullPath,
      });
    }
    return files;
  }

  // Hàm tải và giải nén file .mxl
  Future<String> loadMusicXmlContent(String fullPath) async {
    final ref = FirebaseStorage.instance.ref().child(fullPath);
    final downloadUrl = await ref.getDownloadURL();
    final response = await http.get(Uri.parse(downloadUrl));
    final bytes = response.bodyBytes;

    final archive = ZipDecoder().decodeBytes(bytes);
    for (var file in archive) {
      if (file.name.endsWith('.xml')) {
        return String.fromCharCodes(file.content as List<int>);
      }
    }
    throw Exception('Không tìm thấy file XML trong .mxl');
  }

  // Hàm phân tích MusicXML
  Future<xml.XmlDocument> parseMusicXml(String xmlContent) async {
    return xml.XmlDocument.parse(xmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phát Sheet Nhạc'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchMusicFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi khi tải danh sách file'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có file nào'));
          }

          final files = snapshot.data!;
          return Column(
            children: [
              // Danh sách các file MusicXML
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(file['name'], style: const TextStyle(fontSize: 20)),
                      onTap: () async {
                        setState(() {
                          selectedSong = file['fullPath'];
                          musicXmlDocument = null; // Reset dữ liệu cũ
                        });
                        try {
                          final xmlContent = await loadMusicXmlContent(file['fullPath']);
                          final parsedXml = await parseMusicXml(xmlContent);
                          setState(() {
                            musicXmlDocument = parsedXml;
                          });
                        } catch (e) {
                          print('Lỗi khi tải hoặc phân tích file: $e');
                        }
                      },
                    );
                  },
                ),
              ),
              // Hiển thị thông tin từ MusicXML
              if (musicXmlDocument != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề
                      Text(
                        'Tiêu đề: ${musicXmlDocument!.findAllElements('movement-title').isNotEmpty ? musicXmlDocument!.findAllElements('movement-title').first.text : 'Không có'}',
                      ),
                      // Tác giả
                      Text(
                        'Tác giả: ${musicXmlDocument!.findAllElements('identification').isNotEmpty ? musicXmlDocument!.findAllElements('identification').first.findAllElements('creator').where((c) => c.getAttribute('type') == 'composer').isNotEmpty ? musicXmlDocument!.findAllElements('identification').first.findAllElements('creator').where((c) => c.getAttribute('type') == 'composer').first.text : 'Không có' : 'Không có'}',
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}