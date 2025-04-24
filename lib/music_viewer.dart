import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:music_xml/music_xml.dart';
import 'package:xml/xml.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class MusicViewer extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isLocalFile;

  const MusicViewer({
    required this.filePath,
    required this.fileName,
    this.isLocalFile = false,
    Key? key,
  }) : super(key: key);

  @override
  State<MusicViewer> createState() => _MusicViewerState();
}

class _MusicViewerState extends State<MusicViewer> {
  bool _isLoading = true;
  String? _fileContent;
  MidiPro? _midiPro;
  int? _sfId;
  List<Map<String, dynamic>> _midiEvents = [];
  bool _isPlaying = false;
  double _tempoMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeMidi();
    _loadMusicFile();
  }

  Future<void> _initializeMidi() async {
    _midiPro = MidiPro();
    final tempDir = await getTemporaryDirectory();
    final soundFontFile = File('${tempDir.path}/Grand_Piano.sf2');
    final soundFontData = await DefaultAssetBundle.of(context).load('assets/Grand_Piano.sf2');
    await soundFontFile.writeAsBytes(soundFontData.buffer.asUint8List());
    _sfId = await _midiPro!.loadSoundfont(path: soundFontFile.path, bank: 0, program: 0);
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
      );
      _fileContent = utf8.decode(xmlFile.content as List<int>);
      await _parseMusicXml(_fileContent!);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _parseMusicXml(String xmlContent) async {
    final document = MusicXmlDocument.parse(xmlContent);
    final scorePartwise = document.score.getElement('score-partwise');
    if (scorePartwise == null) throw Exception('Invalid MusicXML: No score-partwise found');

    _midiEvents.clear();
    double currentTime = 0.0;
    double baseTempo = 120.0; // Default tempo
    int divisions = 1;
    Map<String, int> keySignature = {};

    // Check for global tempo in the first part's first measure
    final firstPart = scorePartwise.findAllElements('part').firstOrNull;
    final firstMeasure = firstPart?.findAllElements('measure').firstOrNull;
    if (firstMeasure != null) {
      final direction = firstMeasure.getElement('direction');
      if (direction != null) {
        // Check <sound> element for tempo
        final soundTempo = direction.getElement('sound')?.getAttribute('tempo');
        if (soundTempo != null) {
          baseTempo = double.parse(soundTempo);
        }

        // Check <metronome> element for tempo
        final metronome = direction.getElement('direction-type')?.getElement('metronome');
        if (metronome != null) {
          final beatUnit = metronome.getElement('beat-unit')?.innerText;
          final perMinute = metronome.getElement('per-minute')?.innerText;
          if (beatUnit != null && perMinute != null) {
            // Assuming beat-unit is a quarter note (most common)
            if (beatUnit == 'quarter') {
              baseTempo = double.parse(perMinute);
            }
          }
        }
      }
    }

    for (var part in scorePartwise.findAllElements('part')) {
      for (var measure in part.findAllElements('measure')) {
        // Update attributes (divisions and key signature)
        final attributes = measure.getElement('attributes');
        if (attributes != null) {
          final divisionsElement = attributes.getElement('divisions');
          divisions = divisionsElement != null
              ? int.parse(divisionsElement.innerText)
              : divisions;
          divisions = divisions > 0 ? divisions : 1;

          final keyElement = attributes.getElement('key');
          if (keyElement != null) {
            final fifths = int.parse(keyElement.getElement('fifths')?.innerText ?? '0');
            keySignature = _getKeySignatureAlterations(fifths);
          }
        }

        // Update tempo if present in this measure
        final direction = measure.getElement('direction');
        if (direction != null) {
          // Check <sound> element
          final soundTempo = direction.getElement('sound')?.getAttribute('tempo');
          if (soundTempo != null) {
            baseTempo = double.parse(soundTempo);
          }

          // Check <metronome> element
          final metronome = direction.getElement('direction-type')?.getElement('metronome');
          if (metronome != null) {
            final beatUnit = metronome.getElement('beat-unit')?.innerText;
            final perMinute = metronome.getElement('per-minute')?.innerText;
            if (beatUnit != null && perMinute != null && beatUnit == 'quarter') {
              baseTempo = double.parse(perMinute);
            }
          }
        }

        // Process notes
        List<int> chordNotes = [];
        double chordStartTime = currentTime;
        double chordDuration = 0.0;

        for (var element in measure.findAllElements('*')) {
          if (element.name.local == 'note') {
            final pitch = element.getElement('pitch');
            final duration = double.parse(element.getElement('duration')?.innerText ?? '1');
            final durationInSeconds = (duration / divisions) * (60 / baseTempo);

            if (pitch != null) {
              final step = pitch.getElement('step')?.innerText;
              final octave = int.parse(pitch.getElement('octave')?.innerText ?? '4');
              final accidental = element.getElement('accidental')?.innerText;
              final isChord = element.getElement('chord') != null;
              final midiNote = _stepToMidiNote(step, octave, keySignature, accidental);

              if (midiNote != null) {
                if (isChord) {
                  chordNotes.add(midiNote);
                  chordDuration = durationInSeconds;
                } else {
                  if (chordNotes.isNotEmpty) {
                    _midiEvents.add({
                      'midiNotes': List<int>.from(chordNotes),
                      'startTime': chordStartTime,
                      'duration': chordDuration,
                      'baseTempo': baseTempo, // Store the tempo with the event
                    });
                    chordNotes.clear();
                  }
                  chordNotes.add(midiNote);
                  chordStartTime = currentTime;
                  chordDuration = durationInSeconds;
                }
                if (!isChord) currentTime += durationInSeconds;
              }
            } else {
              currentTime += durationInSeconds; // Handle rests
            }
          } else if (element.name.local == 'forward') {
            final duration = double.parse(element.getElement('duration')?.innerText ?? '0');
            currentTime += (duration / divisions) * (60 / baseTempo);
          } else if (element.name.local == 'backup') {
            final duration = double.parse(element.getElement('duration')?.innerText ?? '0');
            currentTime -= (duration / divisions) * (60 / baseTempo);
          }
        }

        if (chordNotes.isNotEmpty) {
          _midiEvents.add({
            'midiNotes': List<int>.from(chordNotes),
            'startTime': chordStartTime,
            'duration': chordDuration,
            'baseTempo': baseTempo,
          });
        }
      }
    }

    _midiEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
  }

  Map<String, int> _getKeySignatureAlterations(int fifths) {
    final sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
    final flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];
    Map<String, int> alterations = {};
    if (fifths > 0) {
      for (int i = 0; i < fifths && i < sharpOrder.length; i++) {
        alterations[sharpOrder[i]] = 1;
      }
    } else if (fifths < 0) {
      for (int i = 0; i < -fifths && i < flatOrder.length; i++) {
        alterations[flatOrder[i]] = -1;
      }
    }
    return alterations;
  }

  int? _stepToMidiNote(String? step, int octave, Map<String, int> keySignature, String? accidental) {
    if (step == null) return null;
    const noteMap = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final base = noteMap[step.toUpperCase()];
    if (base == null) return null;

    int alteration = keySignature[step.toUpperCase()] ?? 0;
    if (accidental != null) {
      alteration = {'sharp': 1, 'flat': -1, 'natural': 0}[accidental] ?? 0;
    }
    return base + alteration + (octave + 1) * 12;
  }

  Future<void> _playMusic() async {
    if (_isPlaying) {
      setState(() => _isPlaying = false); // Stop current playback
      await Future.delayed(const Duration(milliseconds: 100)); // Allow notes to stop
    }

    setState(() => _isPlaying = true);

    final events = [
      ..._midiEvents.map((e) => {
        'midiNotes': e['midiNotes'],
        'time': e['startTime'] / _tempoMultiplier,
        'duration': e['duration'] / _tempoMultiplier,
        'action': 'start',
      }),
      ..._midiEvents.map((e) => {
        'midiNotes': e['midiNotes'],
        'time': (e['startTime'] + e['duration']) / _tempoMultiplier,
        'action': 'stop',
      }),
    ]..sort((a, b) => a['time'].compareTo(b['time']));

    final startTime = DateTime.now();
    int eventIndex = 0;

    while (eventIndex < events.length && _isPlaying && mounted) {
      final elapsedSeconds = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      while (eventIndex < events.length && events[eventIndex]['time'] <= elapsedSeconds) {
        final event = events[eventIndex];
        final midiNotes = event['midiNotes'] as List<int>;
        final action = event['action'] as String;

        for (var midi in midiNotes) {
          if (action == 'start') {
            await _midiPro!.playNote(channel: 0, key: midi, velocity: 127, sfId: _sfId!);
          } else {
            await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
          }
        }
        eventIndex++;
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }

    setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _isPlaying = false;
    if (_midiPro != null && _sfId != null) {
      for (var event in _midiEvents) {
        for (var midi in event['midiNotes'] as List<int>) {
          _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fileContent == null
          ? const Center(child: Text('Error loading file'))
          : MusicContent(
        xmlContent: _fileContent!,
        onPlay: _playMusic,
        onTempoChanged: (value) {
          setState(() {
            _tempoMultiplier = value;
            if (_isPlaying) {
              _playMusic(); // Restart playback with new tempo
            }
          });
        },
      ),
    );
  }
}

class MusicContent extends StatelessWidget {
  final String xmlContent;
  final VoidCallback onPlay;
  final ValueChanged<double> onTempoChanged;

  const MusicContent({
    required this.xmlContent,
    required this.onPlay,
    required this.onTempoChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MusicXmlDocument>(
      future: Future.value(MusicXmlDocument.parse(xmlContent)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final document = snapshot.data!;
          final scorePartwise = document.score.getElement('score-partwise');
          final movementTitle = scorePartwise?.getElement('movement-title')?.innerText ?? 'Unknown';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: $movementTitle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Total Time: ${document.totalTimeSecs} seconds'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onPlay, child: const Text('Play Music')),
                const SizedBox(height: 16),
                const Text('Adjust Tempo:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Slider(
                  value: context.findAncestorStateOfType<_MusicViewerState>()?._tempoMultiplier ?? 1.0,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${((context.findAncestorStateOfType<_MusicViewerState>()?._tempoMultiplier ?? 1.0) * 100).toInt()}%',
                  onChanged: onTempoChanged,
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('No data available'));
      },
    );
  }
}