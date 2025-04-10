import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_xml/music_xml.dart';

class PlaySheet extends StatefulWidget {
  const PlaySheet({super.key});

  @override
  State<PlaySheet> createState() => _PlaySheetState();
}

class _PlaySheetState extends State<PlaySheet> {
  String? selectedSong;
  MusicXmlDocument? musicXmlDocument;

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

  // Tải file từ Firebase Storage
  Future<File?> downloadMXLFile(String filePath) async {
    try {
      final ref = FirebaseStorage.instance.ref(filePath);
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory(); // Thư mục hợp lệ
        final file = File('${directory.path}/${filePath.split('/').last}'); // Lưu tại đây
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      print('Lỗi tải file: $e');
    }
    return null;
  }

  // Giải nén file .mxl để lấy file .xml
  Future<String?> extractMusicXML(File mxlFile) async {
    try {
      final bytes = await mxlFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (var file in archive) {
        if (file.name.endsWith('.xml')) {
          return utf8.decode(file.content as List<int>);
        }
      }
    } catch (e) {
      print('Lỗi giải nén file: $e');
    }
    return null;
  }

  // Tải, giải nén và phân tích file .mxl
  Future<void> loadAndParseMXL(String filePath) async {
    setState(() {
      selectedSong = filePath;
      musicXmlDocument = null;
    });

    try {
      final mxlFile = await downloadMXLFile(filePath);
      if (mxlFile != null) {
        final xmlString = await extractMusicXML(mxlFile);
        if (xmlString != null) {
          final parsedXml = MusicXmlDocument.parse(xmlString);
          setState(() {
            musicXmlDocument = parsedXml;
          });
        }
      }
    } catch (e) {
      print('Lỗi xử lý file .mxl: $e');
    }
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
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(file['name'], style: const TextStyle(fontSize: 20)),
                      onTap: () async {
                        await loadAndParseMXL(file['fullPath']);
                      },
                    );
                  },
                ),
              ),
              if (musicXmlDocument != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('movement-title: ${musicXmlDocument!.score.getElement('score-partwise')}'),
                      const SizedBox(height: 16),
                      Text('Tổng thời gian: ${musicXmlDocument!.totalTimeSecs} giây'),
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
