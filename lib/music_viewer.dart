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
import 'package:simple_sheet_music/simple_sheet_music.dart';

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
    final soundFontData = await DefaultAssetBundle.of(
      context,
    ).load('assets/Grand_Piano.sf2');
    await soundFontFile.writeAsBytes(soundFontData.buffer.asUint8List());
    _sfId = await _midiPro!.loadSoundfont(
      path: soundFontFile.path,
      bank: 0,
      program: 0,
    );
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
        await _parseMusicXml(_fileContent!);
      } catch (e) {
        print('Error parsing MusicXML: $e');
        setState(() {
          _fileContent = null;
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _parseMusicXml(String xmlContent) async {
    final document = MusicXmlDocument.parse(xmlContent);
    final scorePartwise = document.score.getElement('score-partwise');
    if (scorePartwise == null)
      throw Exception('Invalid MusicXML: No score-partwise found');

    _midiEvents.clear();
    double currentTime = 0.0;
    double baseTempo = 120.0; // Giá trị mặc định, sẽ được cập nhật nếu tìm thấy
    int divisions = 1;
    Map<String, int> keySignature = {};
    Map<String, int> measureAccidentals = {};
    List<Map<String, dynamic>> tempMidiEvents =
        []; // Lưu tạm MIDI events trước khi xử lý repeat
    List<int> repeatStartMeasures = []; // Lưu số thứ tự measure bắt đầu repeat
    List<int> repeatEndMeasures = []; // Lưu số thứ tự measure kết thúc repeat
    int measureCount = 0;

    // Tìm tempo trong toàn bộ file
    for (var part in scorePartwise.findAllElements('part')) {
      for (var measure in part.findAllElements('measure')) {
        final direction = measure.getElement('direction');
        if (direction != null) {
          final soundTempo = direction
              .getElement('sound')
              ?.getAttribute('tempo');
          if (soundTempo != null) {
            baseTempo = double.parse(soundTempo);
            break;
          }
          final metronome = direction
              .getElement('direction-type')
              ?.getElement('metronome');
          if (metronome != null) {
            final beatUnit = metronome.getElement('beat-unit')?.innerText;
            final perMinute = metronome.getElement('per-minute')?.innerText;
            if (beatUnit != null &&
                perMinute != null &&
                beatUnit == 'quarter') {
              baseTempo = double.parse(perMinute);
              break;
            }
          }
        }
      }
      if (baseTempo != 120.0)
        break; // Thoát vòng lặp part nếu đã tìm thấy tempo
    }

    // Xử lý các measure
    for (var part in scorePartwise.findAllElements('part')) {
      measureCount = 0;
      for (var measure in part.findAllElements('measure')) {
        measureCount++;
        measureAccidentals.clear();

        // Xử lý barline để tìm repeat
        for (var barline in measure.findAllElements('barline')) {
          final repeat = barline.getElement('repeat');
          if (repeat != null) {
            final direction = repeat.getAttribute('direction');
            if (direction == 'forward') {
              repeatStartMeasures.add(measureCount);
            } else if (direction == 'backward') {
              repeatEndMeasures.add(measureCount);
            }
          }
        }

        final attributes = measure.getElement('attributes');
        if (attributes != null) {
          final divisionsElement = attributes.getElement('divisions');
          divisions =
              divisionsElement != null
                  ? int.parse(divisionsElement.innerText)
                  : divisions;
          divisions = divisions > 0 ? divisions : 1;

          final keyElement = attributes.getElement('key');
          if (keyElement != null) {
            final fifths = int.parse(
              keyElement.getElement('fifths')?.innerText ?? '0',
            );
            keySignature = _getKeySignatureAlterations(fifths);
          }
        }

        final direction = measure.getElement('direction');
        if (direction != null) {
          final soundTempo = direction
              .getElement('sound')
              ?.getAttribute('tempo');
          if (soundTempo != null) {
            baseTempo = double.parse(soundTempo);
          }
          final metronome = direction
              .getElement('direction-type')
              ?.getElement('metronome');
          if (metronome != null) {
            final beatUnit = metronome.getElement('beat-unit')?.innerText;
            final perMinute = metronome.getElement('per-minute')?.innerText;
            if (beatUnit != null &&
                perMinute != null &&
                beatUnit == 'quarter') {
              baseTempo = double.parse(perMinute);
            }
          }
        }

        List<int> chordNotes = [];
        double chordStartTime = currentTime;
        double chordDuration = 0.0;

        for (var element in measure.findAllElements('*')) {
          if (element.name.local == 'note') {
            final pitch = element.getElement('pitch');
            final duration = double.parse(
              element.getElement('duration')?.innerText ?? '1',
            );
            final durationInSeconds = (duration / divisions) * (60 / baseTempo);
            bool isFermata = false;
            bool isStaccato = false;
            bool isSlurStart = false;
            bool isSlurEnd = false;

            // Kiểm tra notations
            final notations = element.getElement('notations');
            if (notations != null) {
              if (notations.getElement('fermata') != null) {
                isFermata = true;
              }
              final articulations = notations.getElement('articulations');
              if (articulations?.getElement('staccato') != null) {
                isStaccato = true;
              }
              for (var slur in notations.findAllElements('slur')) {
                final type = slur.getAttribute('type');
                if (type == 'start')
                  isSlurStart = true;
                else if (type == 'stop')
                  isSlurEnd = true;
              }
            }

            if (pitch != null) {
              final step = pitch.getElement('step')?.innerText;
              final octave = int.parse(
                pitch.getElement('octave')?.innerText ?? '4',
              );
              final accidental = element.getElement('accidental')?.innerText;
              final isChord = element.getElement('chord') != null;
              final noteKey = '$step$octave';
              final midiNote = _stepToMidiNote(
                step,
                octave,
                keySignature,
                accidental,
                measureAccidentals,
                noteKey,
              );

              if (midiNote != null) {
                double adjustedDuration = durationInSeconds;
                if (isFermata) {
                  adjustedDuration *= 1.5; // Kéo dài 1.5 lần cho fermata
                }
                if (isStaccato) {
                  adjustedDuration *= 0.5; // Rút ngắn 0.5 lần cho staccato
                }

                if (isChord) {
                  chordNotes.add(midiNote);
                  chordDuration = adjustedDuration;
                } else {
                  if (chordNotes.isNotEmpty) {
                    tempMidiEvents.add({
                      'midiNotes': List<int>.from(chordNotes),
                      'startTime': chordStartTime,
                      'duration': chordDuration,
                      'baseTempo': baseTempo,
                      'isSlurStart': isSlurStart,
                      'isSlurEnd': isSlurEnd,
                      'measure': measureCount,
                    });
                    chordNotes.clear();
                  }
                  chordNotes.add(midiNote);
                  chordStartTime = currentTime;
                  chordDuration = adjustedDuration;
                }
                if (!isChord) currentTime += durationInSeconds;
              }
            } else {
              currentTime += durationInSeconds;
            }
          } else if (element.name.local == 'forward') {
            final duration = double.parse(
              element.getElement('duration')?.innerText ?? '0',
            );
            currentTime += (duration / divisions) * (60 / baseTempo);
          } else if (element.name.local == 'backup') {
            final duration = double.parse(
              element.getElement('duration')?.innerText ?? '0',
            );
            currentTime -= (duration / divisions) * (60 / baseTempo);
          }
        }

        if (chordNotes.isNotEmpty) {
          tempMidiEvents.add({
            'midiNotes': List<int>.from(chordNotes),
            'startTime': chordStartTime,
            'duration': chordDuration,
            'baseTempo': baseTempo,
            'isSlurStart': false,
            'isSlurEnd': false,
            'measure': measureCount,
          });
        }
      }
    }

    // Xử lý repeat để tạo _midiEvents
    _midiEvents = _processRepeats(
      tempMidiEvents,
      repeatStartMeasures,
      repeatEndMeasures,
    );

    _midiEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
  }

  List<Map<String, dynamic>> _processRepeats(
    List<Map<String, dynamic>> events,
    List<int> startMeasures,
    List<int> endMeasures,
  ) {
    List<Map<String, dynamic>> finalEvents = [];
    int currentMeasure = 1;
    int repeatIndex = 0;
    bool inRepeat = false;
    double timeOffset = 0.0;

    for (var event in events) {
      final measure = event['measure'] as int;

      // Kiểm tra nếu bắt đầu repeat
      if (startMeasures.contains(measure) && !inRepeat) {
        inRepeat = true;
        repeatIndex++;
      }

      // Thêm event vào danh sách
      final newEvent = Map<String, dynamic>.from(event);
      newEvent['startTime'] = event['startTime'] + timeOffset;
      finalEvents.add(newEvent);

      // Kiểm tra nếu kết thúc repeat
      if (endMeasures.contains(measure) && inRepeat) {
        inRepeat = false;
        // Quay lại measure bắt đầu repeat
        final startMeasure = startMeasures[repeatIndex - 1];
        final repeatEvents =
            events
                .where(
                  (e) =>
                      e['measure'] >= startMeasure && e['measure'] <= measure,
                )
                .toList();
        // Tính thời gian của đoạn repeat
        final repeatDuration =
            repeatEvents.last['startTime'] +
            repeatEvents.last['duration'] -
            repeatEvents.first['startTime'];
        timeOffset += repeatDuration;
        // Thêm lại các event của đoạn repeat
        for (var repeatEvent in repeatEvents) {
          final newRepeatEvent = Map<String, dynamic>.from(repeatEvent);
          newRepeatEvent['startTime'] = repeatEvent['startTime'] + timeOffset;
          finalEvents.add(newRepeatEvent);
        }
      }
    }

    return finalEvents;
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

  int? _stepToMidiNote(
    String? step,
    int octave,
    Map<String, int> keySignature,
    String? accidental,
    Map<String, int> measureAccidentals,
    String noteKey,
  ) {
    if (step == null) return null;
    const noteMap = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final base = noteMap[step.toUpperCase()];
    if (base == null) return null;

    int alteration = keySignature[step.toUpperCase()] ?? 0;

    if (measureAccidentals.containsKey(noteKey)) {
      alteration = measureAccidentals[noteKey]!;
    }

    if (accidental != null) {
      alteration =
          {
            'sharp': 1,
            'flat': -1,
            'natural': 0,
            'double-sharp': 2,
            'double-flat': -2,
            'sharp-sharp': 2,
            'flat-flat': -2,
          }[accidental] ??
          0;
      measureAccidentals[noteKey] = alteration;
    }

    return base + alteration + (octave + 1) * 12;
  }

  Future<void> _playMusic() async {
    _isPlaying = false;
    await Future.delayed(const Duration(milliseconds: 100));
    for (var event in _midiEvents) {
      for (var midi in event['midiNotes'] as List<int>) {
        await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
      }
    }

    setState(() => _isPlaying = true);

    final events = [
      ..._midiEvents.map(
        (e) => {
          'midiNotes': e['midiNotes'],
          'time': e['startTime'] / _tempoMultiplier,
          'duration': e['duration'] / _tempoMultiplier,
          'action': 'start',
          'isSlurStart': e['isSlurStart'] ?? false,
          'isSlurEnd': e['isSlurEnd'] ?? false,
        },
      ),
      ..._midiEvents.map(
        (e) => {
          'midiNotes': e['midiNotes'],
          'time': (e['startTime'] + e['duration']) / _tempoMultiplier,
          'action': 'stop',
          'isSlurStart': e['isSlurStart'] ?? false,
          'isSlurEnd': e['isSlurEnd'] ?? false,
        },
      ),
    ]..sort((a, b) => a['time'].compareTo(b['time']));

    final startTime = DateTime.now();
    int eventIndex = 0;

    while (eventIndex < events.length && _isPlaying && mounted) {
      final elapsedSeconds =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      while (eventIndex < events.length &&
          events[eventIndex]['time'] <= elapsedSeconds &&
          _isPlaying) {
        final event = events[eventIndex];
        final midiNotes = event['midiNotes'] as List<int>;
        final action = event['action'] as String;
        final isSlurStart = event['isSlurStart'] as bool;
        final isSlurEnd = event['isSlurEnd'] as bool;
        int velocity = 127;

        if (isSlurStart || isSlurEnd) {
          velocity = 100; // Giảm velocity để nốt mượt hơn
        }

        for (var midi in midiNotes) {
          if (action == 'start') {
            await _midiPro!.playNote(
              channel: 0,
              key: midi,
              velocity: velocity,
              sfId: _sfId!,
            );
          } else {
            await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
          }
        }
        eventIndex++;
      }

      if (!_isPlaying) break;
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _rewindMusic() async {
    if (_isPlaying) {
      await _playMusic();
    }
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _fileContent == null
              ? const Center(
                child: Text(
                  'Error: Unable to parse this MusicXML file. It may contain unsupported elements or special characters.',
                ),
              )
              : MusicContent(
                xmlContent: _fileContent!,
                onPlay: () {
                  if (_isPlaying) {
                    setState(() => _isPlaying = false);
                  } else {
                    _playMusic();
                  }
                },
                onRewind: _rewindMusic,
                isPlaying: _isPlaying,
                onTempoChanged: (value) {
                  setState(() {
                    _tempoMultiplier = value;
                    if (_isPlaying) {
                      _playMusic();
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
  final VoidCallback onRewind;
  final bool isPlaying;
  final ValueChanged<double> onTempoChanged;

  const MusicContent({
    required this.xmlContent,
    required this.onPlay,
    required this.onRewind,
    required this.isPlaying,
    required this.onTempoChanged,
    Key? key,
  }) : super(key: key);

  Widget build(BuildContext context) {
    return FutureBuilder<MusicXmlDocument>(
      future: Future.value(MusicXmlDocument.parse(xmlContent)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final document = snapshot.data!;
          final scorePartwise = document.score.getElement('score-partwise');
          final movementTitle =
              scorePartwise?.getElement('movement-title')?.innerText ??
                  'Unknown';
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề bản nhạc
                      Text(
                        'Title: $movementTitle',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Hiển thị sheet nhạc
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SimpleSheetMusic(
                          key: key,
                          measures: [
                          ],
                          initialClefType: ClefType.treble,
                          initialKeySignatureType: KeySignatureType.cMajor,
                          height: 400.0,
                          width: 400.0,
                          lineColor: Colors.black54,
                          fontType: FontType.bravura,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tổng thời gian
                      Text('Total Time: ${document.totalTimeSecs} seconds'),
                      const SizedBox(height: 16),
                      // Điều chỉnh tempo
                      const Text(
                        'Adjust Tempo:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value:
                            context
                                .findAncestorStateOfType<_MusicViewerState>()
                                ?._tempoMultiplier ??
                            1.0,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label:
                            '${((context.findAncestorStateOfType<_MusicViewerState>()?._tempoMultiplier ?? 1.0) * 100).toInt()}%',
                        onChanged: onTempoChanged,
                      ),
                    ],
                  ),
                ),
              ),
              // Nút điều khiển phát/tua lại
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay),
                      onPressed: onRewind,
                      tooltip: 'Rewind',
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: onPlay,
                      tooltip: isPlaying ? 'Pause' : 'Play',
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return const Center(child: Text('No data available'));
      },

    );
  }
}
