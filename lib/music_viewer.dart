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
    File fileToRead;
    if (widget.isLocalFile) {
      fileToRead = File(widget.filePath);
    } else {
      final ref = FirebaseStorage.instance.ref(widget.filePath);
      final url = await ref.getDownloadURL();
      final tempDir = await getTemporaryDirectory();
      fileToRead = File('${tempDir.path}/${widget.fileName}');
      final response = await http.get(Uri.parse(url));
      await fileToRead.writeAsBytes(response.bodyBytes);
    }

    if (widget.fileName.toLowerCase().endsWith('.mxl')) {
      final bytes = await fileToRead.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
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
          _fileContent = null;
        });
      }
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
      await _playMusic();
    }
  }

  @override
  void dispose() {
    _midiHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fileContent == null
          ? const Center(
        child: Text(
          'Error: Unable to parse this MusicXML file. It may contain unsupported elements or special characters.',
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