import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:flutter_piano_pro/flutter_piano_pro.dart';
import 'package:flutter_piano_pro/note_model.dart';
import 'package:flutter/services.dart';

class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({super.key});

  @override
  State<PianoKeyboard> createState() => _MyAppState();
}

class _MyAppState extends State<PianoKeyboard> {
  final MidiPro midiPro = MidiPro();
  final ValueNotifier<Map<int, String>> loadedSoundfonts = ValueNotifier<Map<int, String>>({});
  final ValueNotifier<int?> selectedSfId = ValueNotifier<int?>(null);
  final ValueNotifier<int> noteCount = ValueNotifier<int>(17);
  final ValueNotifier<bool> showNames = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showOctave = ValueNotifier<bool>(false);
  Map<int, NoteModel> pointerAndNote = {};

  Map<int, Color> getPianoButtonColors(int noteCount) {
    Map<int, Color> colors = {};

    // Bắt đầu từ C3 (MIDI 48)
    int startMidi = 48;

    // Tính số quãng tám đầy đủ (mỗi quãng tám có 7 phím trắng)
    int fullOctaves = (noteCount / 7).floor();
    int remainingWhiteKeys = noteCount % 7;

    // Tính tổng số phím (bao gồm cả phím trắng và phím đen)
    int totalKeys = fullOctaves * 12; // Mỗi quãng tám có 12 phím
    if (remainingWhiteKeys > 0) {
      List<int> whiteKeyPositions = [0, 2, 4, 5, 7, 9, 11]; // Vị trí của phím trắng trong quãng tám
      for (int i = 0; i < remainingWhiteKeys; i++) {
        totalKeys += whiteKeyPositions[i] + 1;
      }
    }

    // Tính MIDI cuối
    int endMidi = startMidi + totalKeys - 1;

    // Gán màu cho tất cả các phím trong phạm vi MIDI
    for (int midi = startMidi; midi <= endMidi; midi++) {
      bool isWhiteKey = ![1, 3, 6, 8, 10].contains(midi % 12);

      if (isWhiteKey) {
        colors[midi] = Colors.white; // Phím trắng: màu trắng sáng
      } else {
        colors[midi] = Colors.black; // Phím đen: màu đen
      }
    }

    return colors;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadDefaultSoundfont();
  }

  Future<void> _loadDefaultSoundfont() async {
    try {
      final int sfId = await loadSoundfont('assets/Grand_Piano.sf2');
      selectedSfId.value = sfId;
      await selectInstrument(sfId: sfId);
    } catch (e) {
      print('Error loading SoundFont: $e');
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (selectedSfId.value != null) {
      unloadSoundfont(selectedSfId.value!);
    }
    super.dispose();
  }

  Future<int> loadSoundfont(String path) async {
    if (loadedSoundfonts.value.containsValue(path)) {
      print('Soundfont file: $path already loaded. Returning ID.');
      return loadedSoundfonts.value.entries.firstWhere((element) => element.value == path).key;
    }
    final int sfId = await midiPro.loadSoundfont(path: path, bank: 0, program: 0);
    loadedSoundfonts.value = {sfId: path, ...loadedSoundfonts.value};
    print('Loaded soundfont file: $path with ID: $sfId');
    return sfId;
  }

  Future<void> selectInstrument({required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) {
      return;
    }
    selectedSfId.value = sfId;
    print('Selected soundfont file: $sfId');
    await midiPro.selectInstrument(sfId: sfId, channel: 0, bank: 0, program: 0);
  }

  Future<void> playNote({required int key, required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) {
      return;
    }
    await midiPro.playNote(channel: 0, key: key, velocity: 127, sfId: sfId);
  }

  Future<void> stopNote({required int key, required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) {
      return;
    }
    await midiPro.stopNote(channel: 0, key: key, sfId: sfId);
  }

  Future<void> unloadSoundfont(int sfId) async {
    await midiPro.unloadSoundfont(sfId);
    loadedSoundfonts.value = {
      for (final entry in loadedSoundfonts.value.entries)
        if (entry.key != sfId) entry.key: entry.value,
    };
    if (selectedSfId.value == sfId) selectedSfId.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.white,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bàn phím Piano',
                style: TextStyle(color: Colors.white),
              ),
              ValueListenableBuilder(
                valueListenable: noteCount,
                builder: (context, value, child) {
                  return Row(
                    children: [
                      const Text(
                        'Số phím: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      Slider(
                        value: value.toDouble(),
                        min: 7,
                        max: 36,
                        divisions: 29,
                        label: value.toString(),
                        onChanged: (newValue) {
                          noteCount.value = newValue.toInt();
                        },
                      ),
                      Text(
                        '$value',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
              ValueListenableBuilder(
                valueListenable: showNames,
                builder: (context, value, child) {
                  return Row(
                    children: [
                      const Text(
                        'Tên phím',
                        style: TextStyle(color: Colors.white),
                      ),
                      Switch(
                        value: value,
                        onChanged: (newValue) {
                          showNames.value = newValue;
                        },
                        activeColor: Colors.white,
                      ),
                    ],
                  );
                },
              ),
              ValueListenableBuilder(
                valueListenable: showOctave,
                builder: (context, value, child) {
                  return Row(
                    children: [
                      const Text(
                        'Quãng tám',
                        style: TextStyle(color: Colors.white),
                      ),
                      Switch(
                        value: value,
                        onChanged: (newValue) {
                          showOctave.value = newValue;
                        },
                        activeColor: Colors.white,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        body: ValueListenableBuilder(
          valueListenable: selectedSfId,
          builder: (context, selectedSfIdValue, child) {
            return Stack(
              children: [
                ValueListenableBuilder(
                  valueListenable: noteCount,
                  builder: (context, noteCountValue, child) {
                    return ValueListenableBuilder(
                      valueListenable: showNames,
                      builder: (context, showNameValue, child) {
                        return ValueListenableBuilder(
                          valueListenable: showOctave,
                          builder: (context, showOctaveValue, child) {
                            return PianoPro(
                              whiteHeight: 280,
                              blackWidthRatio: 1.2,
                              buttonColors: getPianoButtonColors(noteCountValue),
                              showOctave: showOctaveValue,
                              showNames: showNameValue,
                              noteCount: noteCountValue,
                              onTapDown: (NoteModel? note, int tapId) {
                                if (note == null || selectedSfIdValue == null) return;
                                pointerAndNote[tapId] = note;
                                playNote(
                                  key: note.midiNoteNumber,
                                  sfId: selectedSfIdValue,
                                );
                                debugPrint(
                                  'DOWN: note= ${note.name + note.octave.toString() + (note.isFlat ? "♭" : '')}, tapId= $tapId',
                                );
                              },
                              onTapUpdate: (NoteModel? note, int tapId) {
                                if (note == null || selectedSfIdValue == null) return;
                                if (pointerAndNote[tapId] == note) return;
                                stopNote(
                                  key: pointerAndNote[tapId]!.midiNoteNumber,
                                  sfId: selectedSfIdValue,
                                );
                                pointerAndNote[tapId] = note;
                                playNote(
                                  key: note.midiNoteNumber,
                                  sfId: selectedSfIdValue,
                                );
                                debugPrint(
                                  'UPDATE: note= ${note.name + note.octave.toString() + (note.isFlat ? "♭" : '')}, tapId= $tapId',
                                );
                              },
                              onTapUp: (int tapId) {
                                if (selectedSfIdValue == null) return;
                                stopNote(
                                  key: pointerAndNote[tapId]!.midiNoteNumber,
                                  sfId: selectedSfIdValue,
                                );
                                pointerAndNote.remove(tapId);
                                debugPrint('UP: tapId= $tapId');
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                if (selectedSfIdValue == null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}