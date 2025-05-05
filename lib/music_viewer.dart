import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'music_content.dart';
import 'midi_handler.dart';
import 'music_xml_parser.dart';

class MusicViewer extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isLocalFile;

  const MusicViewer({
    required this.filePath,
    required this.fileName,
    this.isLocalFile = false,
    super.key,
  });

  @override
  State<MusicViewer> createState() => _MusicViewerState();
}

class _MusicViewerState extends State<MusicViewer> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _fileContent;
  late MidiHandler _midiHandler;
  List<Map<String, dynamic>> _midiEvents = [];
  bool _isPlaying = false;
  double _tempoMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    _midiHandler = MidiHandler(context);
    _loadMusicFile();
  }

  Future<void> _loadMusicFile() async {
    setState(() => _isLoading = true);
    
    try {
      File fileToRead;
      if (widget.isLocalFile) {
        fileToRead = File(widget.filePath);
      } else {
        final ref = FirebaseStorage.instance.ref(widget.filePath);
        final url = await ref.getDownloadURL();
        final tempDir = await getTemporaryDirectory();
        fileToRead = File('${tempDir.path}/${widget.fileName}.mxl');
        final response = await http.get(Uri.parse(url));
        await fileToRead.writeAsBytes(response.bodyBytes);
      }

      if (widget.filePath.toLowerCase().endsWith('.mxl')) {
        final bytes = await fileToRead.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        // Find the MusicXML file in the archive
        final xmlFile = archive.firstWhere(
          (file) => file.name.endsWith('.xml') && !file.name.contains('META-INF'),
          orElse: () => throw Exception('No MusicXML file found in .mxl archive'),
        );
        
        _fileContent = utf8.decode(xmlFile.content as List<int>);
        
        try {
          _midiEvents = await MusicXmlParser.parseMusicXml(_fileContent!);
        } catch (e) {
          print('Error parsing MusicXML: $e');
          setState(() {
            _hasError = true;
            _errorMessage = 'Error parsing MusicXML: $e';
            _fileContent = null;
          });
        }
      }
    } catch (e) {
      print('Error loading music file: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading music file: $e';
      });
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _playMusic() async {
    if (_isPlaying) {
      setState(() => _isPlaying = false);
      await _midiHandler.stopMusic();
    } else {
      setState(() => _isPlaying = true);
      await _midiHandler.playMusic(_midiEvents, _tempoMultiplier, () {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  Future<void> _rewindMusic() async {
    if (_isPlaying) {
      await _playMusic(); // This stops the music
    }
    // Reset position
    _midiHandler.seekToPosition(0, 0);
  }

  @override
  void dispose() {
    _midiHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.fileName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueGrey),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải bản nhạc...',
                    style: TextStyle(color: Colors.white),
                  )
                ],
              ),
            )
          : _hasError || _fileContent == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Không thể hiển thị bản nhạc này. Định dạng có thể không được hỗ trợ.',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadMusicFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Thử lại'),
                        )
                      ],
                    ),
                  ),
                )
              : MusicContent(
                  xmlContent: _fileContent!,
                  onPlay: _playMusic,
                  onRewind: _rewindMusic,
                  isPlaying: _isPlaying,
                  tempoMultiplier: _tempoMultiplier,
                  onTempoChanged: (value) {
                    setState(() {
                      _tempoMultiplier = value;
                      if (_isPlaying) {
                        _playMusic();
                      }
                    });
                  },
                  filePath: widget.filePath,
                  playbackPositionStream: _midiHandler.positionStream,
                  onNoteChanged: (measure, note) {
                    _midiHandler.seekToPosition(measure, note);
                  },
                ),
    );
  }
}