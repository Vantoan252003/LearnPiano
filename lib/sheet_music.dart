import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart' as xml;
import 'package:flutter_midi/flutter_midi.dart';

class SheetMusic extends StatefulWidget {
  const SheetMusic({super.key});
  @override
  State<SheetMusic> createState() => _SheetMusicState();
}

class _SheetMusicState extends State<SheetMusic> {
  String? localPath; // Đường dẫn file MusicXML tạm thời
  bool isLoading = true; // Trạng thái tải file
  List<Map<String, dynamic>> notes = []; // Danh sách nốt nhạc
  final FlutterMidi _flutterMidi = FlutterMidi();

  @override
  void initState() {
    super.initState();
    _initMidi();
    _loadSheetMusic();
  }

  // Khởi tạo MIDI
  Future<void> _initMidi() async {
    // Tải SoundFont (.sf2) từ assets okok
    // Đảm bảo bạn đã thêm file SoundFont (ví dụ: Piano.sf2) vào assets
    await _flutterMidi.prepare(sf2: await DefaultAssetBundle.of(context).load('assets/1115_Korg_IS50_Marimboyd.sf2'));
  }

  // Tải file MusicXML từ Firebase Storage
  Future<void> _loadSheetMusic() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('sheets/song1.xml');
      final url = await ref.getDownloadURL();

      // Tải file và lưu tạm thời
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/song1.xml');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      await tempFile.writeAsBytes(bytes);

      // Phân tích file MusicXML
      final xmlString = await tempFile.readAsString();
      final document = xml.XmlDocument.parse(xmlString);
      _parseMusicXml(document);

      setState(() {
        localPath = tempFile.path;
        isLoading = false;
      });
    } catch (e) {
      print('Error load MusicXML: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Phân tích file MusicXML để lấy danh sách nốt
  void _parseMusicXml(xml.XmlDocument document) {
    final measures = document.findAllElements('measure');
    for (var measure in measures) {
      final notesInMeasure = measure.findAllElements('note');
      for (var note in notesInMeasure) {
        final pitch = note.findElements('pitch').firstOrNull;
        if (pitch != null) {
          final step = pitch.findElements('step').firstOrNull?.text; // Ví dụ: C, D, E
          final octave = int.parse(pitch.findElements('octave').first.text); // Octave: 0-9
          final duration = int.parse(note.findElements('duration').first.text); // Độ dài nốt
          final midiNote = _convertToMidiNote(step, octave); // Chuyển thành số MIDI
          notes.add({
            'midi': midiNote,
            'duration': duration * 100, // Chuyển đổi duration thành milliseconds (điều chỉnh theo nhịp)
          });
        }
      }
    }
  }

  // Chuyển step và octave thành số MIDI
  int _convertToMidiNote(String? step, int octave) {
    const noteMap = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final noteValue = noteMap[step] ?? 0;
    return (octave + 1) * 12 + noteValue; // Công thức tính số MIDI
  }

  // Phát danh sách nốt
  void _playNotes() async {
    for (var note in notes) {
      _flutterMidi.playMidiNote(midi: note['midi']);
      await Future.delayed(Duration(milliseconds: note['duration']));
      _flutterMidi.stopMidiNote(midi: note['midi']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        title: const Text(
          "Sheet nhạc",
          style: TextStyle(fontSize: 30, color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : localPath != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Sheet nhạc đã tải",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _playNotes,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text(
                "Phát nhạc",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : const Center(
        child: Text(
          "Không thể tải sheet nhạc",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (localPath != null) {
      File(localPath!).delete();
    }
    _flutterMidi.unmute();
    super.dispose();
  }
}