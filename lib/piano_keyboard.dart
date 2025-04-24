import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:flutter_piano_pro/flutter_piano_pro.dart';
import 'package:flutter_piano_pro/note_model.dart';
import 'package:flutter/services.dart';

class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({super.key});

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final MidiPro midiPro = MidiPro();
  final ValueNotifier<Map<int, String>> loadedSoundfonts = ValueNotifier<Map<int, String>>({});
  final ValueNotifier<int?> selectedSfId = ValueNotifier<int?>(null);
  final ValueNotifier<int> noteCount = ValueNotifier<int>(17);
  final ValueNotifier<bool> showNames = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showOctave = ValueNotifier<bool>(false);
  final ValueNotifier<bool> sustainPedal = ValueNotifier<bool>(false);
  final ValueNotifier<Set<int>> pressedKeys = ValueNotifier<Set<int>>({});
  Map<int, NoteModel> pointerAndNote = {};

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
    super.dispose();
  }

  Future<int> loadSoundfont(String path) async {
    if (loadedSoundfonts.value.containsValue(path)) {
      return loadedSoundfonts.value.entries.firstWhere((element) => element.value == path).key;
    }
    final int sfId = await midiPro.loadSoundfont(path: path, bank: 0, program: 0);
    loadedSoundfonts.value = {sfId: path, ...loadedSoundfonts.value};
    return sfId;
  }

  Future<void> selectInstrument({required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) return;
    selectedSfId.value = sfId;
    await midiPro.selectInstrument(sfId: sfId, channel: 0, bank: 0, program: 0);
  }

  Future<void> playNote({required int key, required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) return;
    await midiPro.playNote(channel: 0, key: key, velocity: 127, sfId: sfId);
  }

  Future<void> stopNote({required int key, required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) return;
    await midiPro.stopNote(channel: 0, key: key, sfId: sfId);
  }

  Map<int, Color> getPianoButtonColors(int noteCount, Set<int> pressedKeys) {
    Map<int, Color> colors = {};
    int startMidi = 48; // Bắt đầu từ C3
    int fullOctaves = (noteCount / 7).floor();
    int remainingWhiteKeys = noteCount % 7;
    int totalKeys = fullOctaves * 12;
    if (remainingWhiteKeys > 0) {
      List<int> whiteKeyPositions = [0, 2, 4, 5, 7, 9, 11];
      for (int i = 0; i < remainingWhiteKeys; i++) {
        totalKeys += whiteKeyPositions[i] + 1;
      }
    }
    int endMidi = startMidi + totalKeys - 1;

    for (int midi = startMidi; midi <= endMidi; midi++) {
      bool isWhiteKey = ![1, 3, 6, 8, 10].contains(midi % 12);
      bool isPressed = pressedKeys.contains(midi);
      colors[midi] = isWhiteKey
          ? (isPressed ? Colors.grey[400]! : Colors.white)
          : (isPressed ? Colors.grey[800]! : Colors.black);
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder(
                  valueListenable: sustainPedal,
                  builder: (context, sustainValue, child) {
                    return ValueListenableBuilder(
                      valueListenable: selectedSfId,
                      builder: (context, sfIdValue, child) {
                        return ElevatedButton(
                          onPressed: sfIdValue == null
                              ? null
                              : () {
                            sustainPedal.value = !sustainPedal.value;
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sustainValue ? Colors.blueGrey[700] : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: Text(
                            sustainValue ? 'Sustain: Bật' : 'Sustain: Tắt',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: 20),
                ValueListenableBuilder(
                  valueListenable: noteCount,
                  builder: (context, value, child) {
                    return Row(
                      children: [
                        const Text(
                          'Số phím: ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Slider(
                          value: value.toDouble(),
                          min: 7,
                          max: 36,
                          divisions: 29,
                          label: value.toString(),
                          activeColor: Colors.blueGrey[400],
                          inactiveColor: Colors.grey[600],
                          onChanged: (newValue) {
                            noteCount.value = newValue.toInt();
                          },
                        ),
                        Text(
                          '$value',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 20),
                ValueListenableBuilder(
                  valueListenable: showNames,
                  builder: (context, value, child) {
                    return Row(
                      children: [
                        const Text(
                          'Tên phím: ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Switch(
                          value: value,
                          onChanged: (newValue) {
                            showNames.value = newValue;
                          },
                          activeColor: Colors.blueGrey[400],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 20),
                ValueListenableBuilder(
                  valueListenable: showOctave,
                  builder: (context, value, child) {
                    return Row(
                      children: [
                        const Text(
                          'Quãng tám: ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Switch(
                          value: value,
                          onChanged: (newValue) {
                            showOctave.value = newValue;
                          },
                          activeColor: Colors.blueGrey[400],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
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
                                return ValueListenableBuilder(
                                  valueListenable: pressedKeys,
                                  builder: (context, pressedKeysValue, child) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.grey[900]!, Colors.black],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                      child: PianoPro(
                                        whiteHeight: 300,
                                        blackWidthRatio: 1.3,
                                        buttonColors: getPianoButtonColors(noteCountValue, pressedKeysValue),
                                        showOctave: showOctaveValue,
                                        showNames: showNameValue,
                                        noteCount: noteCountValue,
                                        onTapDown: (NoteModel? note, int tapId) {
                                          if (note == null || selectedSfIdValue == null) return;
                                          pointerAndNote[tapId] = note;
                                          pressedKeys.value = {...pressedKeys.value, note.midiNoteNumber};
                                          playNote(key: note.midiNoteNumber, sfId: selectedSfIdValue);
                                        },
                                        onTapUpdate: (NoteModel? note, int tapId) {
                                          if (note == null || selectedSfIdValue == null) return;
                                          if (pointerAndNote[tapId] == note) return;
                                          stopNote(key: pointerAndNote[tapId]!.midiNoteNumber, sfId: selectedSfIdValue);
                                          pressedKeys.value = pressedKeys.value
                                              .where((key) => key != pointerAndNote[tapId]!.midiNoteNumber)
                                              .toSet();
                                          pointerAndNote[tapId] = note;
                                          pressedKeys.value = {...pressedKeys.value, note.midiNoteNumber};
                                          playNote(key: note.midiNoteNumber, sfId: selectedSfIdValue);
                                        },
                                        onTapUp: (int tapId) {
                                          if (selectedSfIdValue == null || pointerAndNote[tapId] == null) return;
                                          if (!sustainPedal.value) {
                                            stopNote(key: pointerAndNote[tapId]!.midiNoteNumber, sfId: selectedSfIdValue);
                                          }
                                          pressedKeys.value = pressedKeys.value
                                              .where((key) => key != pointerAndNote[tapId]!.midiNoteNumber)
                                              .toSet();
                                          pointerAndNote.remove(tapId);
                                        },
                                      ),
                                    );
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
                          child: const Center(child: CircularProgressIndicator(color: Colors.blueGrey)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}