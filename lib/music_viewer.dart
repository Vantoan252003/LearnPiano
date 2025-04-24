import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_xml/music_xml.dart';
import 'package:xml/xml.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
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
      final Directory tempDir = await getTemporaryDirectory();
      final soundFontFile = File('${tempDir.path}/Grand_Piano.sf2');
      final soundFontData = await DefaultAssetBundle.of(context).load('assets/Grand_Piano.sf2');
      await soundFontFile.writeAsBytes(soundFontData.buffer.asUint8List());
      _sfId = await _midiPro!.loadSoundfont(path: soundFontFile.path, bank: 0, program: 0);

  }

  Future<void> _loadMusicFile() async {
    setState(() {
      _isLoading = true;
    });
      late File fileToRead;
      if (widget.isLocalFile) {
        fileToRead = File(widget.filePath);
      } else {
        final ref = FirebaseStorage.instance.ref(widget.filePath);
        final url = await ref.getDownloadURL();
        final Directory tempDir = await getTemporaryDirectory();
        fileToRead = File('${tempDir.path}/${widget.fileName}');
        final response = await http.get(Uri.parse(url));
        await fileToRead.writeAsBytes(response.bodyBytes);
      }
      if (widget.fileName.toLowerCase().endsWith('.mxl')) {
        final bytes = await fileToRead.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final xmlFile = archive.firstWhere(
              (file) => file.name.endsWith('.xml') && !file.name.contains('META-INF'));
        final xmlContent = utf8.decode(xmlFile.content as List<int>);
        setState(() {
          _fileContent = xmlContent;
        });
        await _parseMusicXml(xmlContent);
      }

  }
  Future<void> _parseMusicXml(String xmlContent) async {
      final document = MusicXmlDocument.parse(xmlContent);
      final scorePartwise = document.score.getElement('score-partwise');
      if (scorePartwise == null) {
        throw Exception('Invalid MusicXML: No score-partwise found');
      }
      _midiEvents.clear();
      final parts = scorePartwise.findAllElements('part').toList();
      double globalTime = 0.0; // Global timeline for all parts
      double baseTempo = 120.0;
      int divisions = 1;
      Map<String, int> keySignature = {};
      for (var part in parts) {
        final measures = part.findAllElements('measure').toList();
        for (var measure in measures) {
          final attributes = measure.getElement('attributes');
          if (attributes != null) {
            final divisionsElement = attributes.getElement('divisions');
            if (divisionsElement != null) {
              divisions = int.parse(divisionsElement.innerText);
              divisions = divisions > 0 ? divisions : 1; // Ensure valid divisions
            }
            final keyElement = attributes.getElement('key');
            if (keyElement != null) {
              final fifths = int.parse(keyElement.getElement('fifths')?.innerText ?? '0');
              keySignature = _getKeySignatureAlterations(fifths);
            }
          }
          final direction = measure.getElement('direction');
          if (direction != null) {
            final sound = direction.getElement('sound');
            if (sound != null && sound.getAttribute('tempo') != null) {
              baseTempo = double.parse(sound.getAttribute('tempo')!);
            }
          }
        }
      }
      List<Map<String, dynamic>> tempEvents = [];
      for (var part in parts) {
        double localTime = 0.0; // Local time for alignment
        final measures = part.findAllElements('measure').toList();
        for (var measure in measures) {
          final elements = measure.findAllElements('*').toList(); // Process all elements
          List<int> chordNotes = [];
          double chordStartTime = globalTime + localTime;
          double chordDuration = 0.0;

          for (var element in elements) {
            if (element.name.local == 'note') {
              final note = element;
              final pitch = note.getElement('pitch');
              if (pitch != null) {
                final step = pitch.getElement('step')?.innerText;
                final octave = int.parse(pitch.getElement('octave')?.innerText ?? '4');
                final duration = double.parse(note.getElement('duration')?.innerText ?? '1');
                final accidental = note.getElement('accidental')?.innerText;
                final isChord = note.getElement('chord') != null;
                final midiNote = _stepToMidiNote(step, octave, keySignature, accidental);

                if (midiNote != null) {
                  final durationInSeconds = (duration / divisions) * (60 / baseTempo);
                  if (isChord) {
                    chordNotes.add(midiNote);
                    chordDuration = durationInSeconds;
                  } else {
                    if (chordNotes.isNotEmpty) {
                      tempEvents.add({
                        'midiNotes': List<int>.from(chordNotes),
                        'startTime': chordStartTime,
                        'duration': chordDuration,
                        'baseTempo': baseTempo,
                      });
                      chordNotes.clear();
                    }
                    chordNotes.add(midiNote);
                    chordStartTime = globalTime + localTime;
                    chordDuration = durationInSeconds;
                  }
                  localTime += isChord ? 0.0 : durationInSeconds;
                }
              } else {
                // Handle rest or non-pitched note
                final duration = double.parse(note.getElement('duration')?.innerText ?? '1');
                final durationInSeconds = (duration / divisions) * (60 / baseTempo);
                localTime += durationInSeconds;
              }
            } else if (element.name.local == 'forward') {
              final duration = double.parse(element.getElement('duration')?.innerText ?? '0');
              final durationInSeconds = (duration / divisions) * (60 / baseTempo);
              localTime += durationInSeconds;
            } else if (element.name.local == 'backup') {
              final duration = double.parse(element.getElement('duration')?.innerText ?? '0');
              final durationInSeconds = (duration / divisions) * (60 / baseTempo);
              localTime -= durationInSeconds;
            }
          }

          // Save last chord or note
          if (chordNotes.isNotEmpty) {
            tempEvents.add({
              'midiNotes': List<int>.from(chordNotes),
              'startTime': chordStartTime,
              'duration': chordDuration,
              'baseTempo': baseTempo,
            });
          }

          // Update global time after each measure
          globalTime = tempEvents.isNotEmpty ? tempEvents.last['startTime'] + tempEvents.last['duration'] : globalTime;
        }
      }
      // Sort events by startTime
      tempEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
      _midiEvents = tempEvents;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

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
    const noteMap = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final base = noteMap[step.toUpperCase()];
    if (base == null) return null;

    int alteration = 0;
    if (keySignature.containsKey(step.toUpperCase())) {
      alteration = keySignature[step.toUpperCase()]!;
    }
    if (accidental != null) {
      switch (accidental) {
        case 'sharp':
          alteration = 1;
          break;
        case 'flat':
          alteration = -1;
          break;
        case 'natural':
          alteration = 0;
          break;
      }
    }

    return base + alteration + (octave + 1) * 12;
  }

  Future<void> _playMusic() async {
    setState(() {
      _isPlaying = true;
    });

    // Precompute stop times
    List<Map<String, dynamic>> stopEvents = [];
    for (var event in _midiEvents) {
      final midiNotes = event['midiNotes'] as List<int>;
      final startTime = event['startTime'] / _tempoMultiplier;
      final duration = event['duration'] / _tempoMultiplier;
      stopEvents.add({
        'midiNotes': midiNotes,
        'time': startTime + duration,
        'action': 'stop',
      });
    }

    // Combine start and stop events
    List<Map<String, dynamic>> allEvents = [
      ..._midiEvents.map((e) => {
        'midiNotes': e['midiNotes'],
        'time': e['startTime'] / _tempoMultiplier,
        'action': 'start',
      }),
      ...stopEvents,
    ];
    allEvents.sort((a, b) => a['time'].compareTo(b['time']));

    // Playback loop
    final startTime = DateTime.now();
    int eventIndex = 0;

    while (eventIndex < allEvents.length && _isPlaying && mounted) {
      final now = DateTime.now();
      final elapsedSeconds = now.difference(startTime).inMilliseconds / 1000.0;

      while (eventIndex < allEvents.length && allEvents[eventIndex]['time'] <= elapsedSeconds) {
        final event = allEvents[eventIndex];
        final midiNotes = event['midiNotes'] as List<int>;
        final action = event['action'] as String;

        if (action == 'start') {
          for (var midi in midiNotes) {
            await _midiPro!.playNote(channel: 0, key: midi, velocity: 127, sfId: _sfId!);
          }
        } else {
          for (var midi in midiNotes) {
            await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
          }
        }
        eventIndex++;
      }

      // Wait until next event or a small delay
      if (eventIndex < allEvents.length) {
        final nextEventTime = allEvents[eventIndex]['time'];
        final waitTime = (nextEventTime - elapsedSeconds) * 1000;
        if (waitTime > 0) {
          await Future.delayed(Duration(milliseconds: waitTime.clamp(1, 50).toInt()));
        }
      } else {
        break;
      }
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _isPlaying = false;
    if (_midiPro != null && _sfId != null) {
      for (var event in _midiEvents) {
        final midiNotes = event['midiNotes'] as List<int>;
        for (var midi in midiNotes) {
          _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fileContent == null
          ? Center(child: Text('Error:'))
          : _fileContent != null
          ? MusicContent(
        xmlContent: _fileContent!,
        onPlay: _playMusic,
        onTempoChanged: (multiplier) {
          setState(() {
            _tempoMultiplier = multiplier;
          });
        },
      )
          : const Center(child: Text('No content available')),
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
          final score = document.score;
          final scorePartwise = score.getElement('score-partwise');
          final movementTitle = scorePartwise?.getElement('movement-title');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Title: ${movementTitle?.innerText ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Total Time: ${document.totalTimeSecs} seconds'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onPlay,
                  child: const Text('Play Music'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Adjust Tempo:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: (context.findAncestorStateOfType<_MusicViewerState>()?._tempoMultiplier ?? 1.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${((context.findAncestorStateOfType<_MusicViewerState>()?._tempoMultiplier ?? 1.0) * 100).toInt()}%',
                  onChanged: (value) {
                    onTempoChanged(value);
                  },
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