import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

class MelodyRecognitionGame extends StatefulWidget {
  const MelodyRecognitionGame({super.key});

  @override
  State<MelodyRecognitionGame> createState() => _MelodyRecognitionGameState();
}

class _MelodyRecognitionGameState extends State<MelodyRecognitionGame> {
  final MidiPro midiPro = MidiPro();
  int? soundfontId;
  bool isLoading = true;
  List<int> melody = [];
  List<int> userInput = [];
  int score = 0;
  int highScore = 0;
  bool showResult = false;
  bool isCorrect = false;
  int melodyLength = 3;
  String difficulty = 'easy'; // 'easy' or 'hard'
  final List<int> easyNotes = [60, 62, 64, 65, 67, 69, 71]; // C D E F G A B
  final List<int> hardNotes = [
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
  ]; // C C# D D# E F F# G G# A A# B
  List<int> get availableNotes => difficulty == 'easy' ? easyNotes : hardNotes;
  final Map<int, String> noteNames = {
    60: 'C',
    61: 'C#',
    62: 'D',
    63: 'D#',
    64: 'E',
    65: 'F',
    66: 'F#',
    67: 'G',
    68: 'G#',
    69: 'A',
    70: 'A#',
    71: 'B',
    72: 'C5',
    73: 'C#5',
    74: 'D5',
    75: 'D#5',
  };
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _loadSoundfont();
  }

  Future<void> _loadSoundfont() async {
    setState(() {
      isLoading = true;
    });
    soundfontId = await midiPro.loadSoundfont(
      path: 'assets/Grand_Piano.sf2',
      bank: 0,
      program: 0,
    );
    await midiPro.selectInstrument(
      sfId: soundfontId!,
      channel: 0,
      bank: 0,
      program: 0,
    );
    setState(() {
      isLoading = false;
    });
    _generateMelody();
  }

  void _generateMelody() {
    setState(() {
      melody = List.generate(
        melodyLength,
        (_) => availableNotes[random.nextInt(availableNotes.length)],
      );
      userInput.clear();
      showResult = false;
    });
  }

  Future<void> _playMelody() async {
    for (final note in melody) {
      await midiPro.playNote(
        channel: 0,
        key: note,
        velocity: 100,
        sfId: soundfontId!,
      );
      await Future.delayed(const Duration(milliseconds: 600));
      midiPro.stopNote(channel: 0, key: note, sfId: soundfontId!);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _onNotePressed(int midiNote) async {
    if (showResult) return;
    setState(() {
      userInput.add(midiNote);
    });
    await midiPro.playNote(
      channel: 0,
      key: midiNote,
      velocity: 100,
      sfId: soundfontId!,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    midiPro.stopNote(channel: 0, key: midiNote, sfId: soundfontId!);
    if (userInput.length == melody.length) {
      _checkAnswer();
    }
  }

  void _deleteLastNote() {
    if (userInput.isNotEmpty && !showResult) {
      setState(() {
        userInput.removeLast();
      });
    }
  }

  void _checkAnswer() {
    bool correct = true;
    for (int i = 0; i < melody.length; i++) {
      if (userInput[i] != melody[i]) {
        correct = false;
        break;
      }
    }
    setState(() {
      showResult = true;
      isCorrect = correct;
      if (correct) {
        score++;
        if (score > highScore) highScore = score;
      } else {
        score = 0;
      }
    });
  }

  void _nextMelody() {
    setState(() {
      melodyLength = melodyLength < 6 ? melodyLength + 1 : 3;
    });
    _generateMelody();
  }

  void _onDifficultyChanged(String? value) {
    if (value == null) return;
    setState(() {
      difficulty = value;
      melodyLength = 3;
    });
    _generateMelody();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Nhận diện giai điệu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Difficulty selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Chọn mức độ:',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text(
                            'Dễ',
                            style: TextStyle(color: Colors.white),
                          ),
                          selected: difficulty == 'easy',
                          onSelected:
                              (selected) => _onDifficultyChanged('easy'),
                          selectedColor: Colors.green,
                          backgroundColor: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text(
                            'Khó',
                            style: TextStyle(color: Colors.white),
                          ),
                          selected: difficulty == 'hard',
                          onSelected:
                              (selected) => _onDifficultyChanged('hard'),
                          selectedColor: Colors.redAccent,
                          backgroundColor: Colors.grey[700],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Nghe và bấm lại đúng thứ tự các nốt vừa nghe!',
                      style: TextStyle(color: Colors.orange[200], fontSize: 18),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _playMelody,
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Phát giai điệu',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: showResult ? _nextMelody : null,
                          icon: const Icon(
                            Icons.skip_next,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Giai điệu mới',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Số nốt: $melodyLength',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Điểm: $score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Điểm cao nhất: $highScore',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 18),
                    if (showResult)
                      Text(
                        isCorrect ? 'Chính xác! 🎉' : 'Sai rồi! 😢',
                        style: TextStyle(
                          color:
                              isCorrect ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (showResult)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Đáp án: ${melody.map((m) => noteNames[m] ?? m.toString()).join(' - ')}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          availableNotes.map((midi) {
                            return ElevatedButton(
                              onPressed:
                                  showResult
                                      ? null
                                      : () => _onNotePressed(midi),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    userInput.isNotEmpty &&
                                            userInput.length <= melody.length &&
                                            userInput[userInput.length - 1] ==
                                                midi
                                        ? Colors.blueAccent
                                        : Colors.grey[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(48, 48),
                              ),
                              child: Text(
                                noteNames[midi] ?? midi.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 18),
                    if (!showResult)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...userInput.map(
                            (midi) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Chip(
                                label: Text(
                                  noteNames[midi] ?? midi.toString(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.blueGrey[700],
                              ),
                            ),
                          ),
                          if (userInput.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.backspace,
                                color: Colors.orangeAccent,
                              ),
                              onPressed: _deleteLastNote,
                              tooltip: 'Xóa nốt cuối',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
    );
  }

  @override
  void dispose() {
    if (soundfontId != null) {
      midiPro.unloadSoundfont(soundfontId!);
    }
    super.dispose();
  }
}
