import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:learn_piano/auth_service.dart';
import 'package:learn_piano/login_screen.dart';

class EarTrainning extends StatefulWidget {
  const EarTrainning({super.key});
  @override
  State<EarTrainning> createState() => _EarTrainningState();
}

class _EarTrainningState extends State<EarTrainning> {
  final MidiPro midiPro = MidiPro();
  final AuthService _auth = AuthService();
  final ValueNotifier<Map<int, String>> loadedSoundfonts =
      ValueNotifier<Map<int, String>>({});
  final ValueNotifier<int?> selectedSfId = ValueNotifier<int?>(null);

  int? randomNote;
  int score = 0;
  int highScore = 0;
  int totalAttempts = 0;
  bool isPlaying = false;
  List<String> options = [];
  String difficulty = 'easy'; // 'easy' or 'hard'
  final List<String> easyNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final List<String> hardNotes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  Map<String, String> noteAlternatives = {
    'A#': 'Bb',
    'C#': 'Db',
    'D#': 'Eb',
    'F#': 'Gb',
    'G#': 'Ab',
  };
  List<Future<dynamic>> _pendingOperations = [];

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoad();
  }

  Future<void> _checkLoginAndLoad() async {
    if (!mounted) return;

    if (_auth.getCurrentUser() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    print('User logged in: ${_auth.getCurrentUser()?.uid}');
    await _loadDefaultSoundfont();
    await _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    if (!mounted) return;

    int score = await _auth.getHighScore('ear_training');
    if (mounted) {
      setState(() {
        highScore = score;
      });
    }
  }

  Future<void> _loadDefaultSoundfont() async {
    if (!mounted) return;

    final int sfId = await loadSoundfont('assets/Grand_Piano.sf2');
    if (mounted) {
      selectedSfId.value = sfId;
      _startGame();
    }
  }

  Future<int> loadSoundfont(String path) async {
    if (loadedSoundfonts.value.containsValue(path)) {
      return loadedSoundfonts.value.entries
          .firstWhere((element) => element.value == path)
          .key;
    }
    final int sfId = await midiPro.loadSoundfont(
      path: path,
      bank: 0,
      program: 0,
    );
    if (mounted) {
      loadedSoundfonts.value = {sfId: path, ...loadedSoundfonts.value};
    }
    return sfId;
  }

  Future<void> playNote({required int key, required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) return;
    await midiPro.playNote(channel: 0, key: key, velocity: 127, sfId: sfId);
  }

  Future<void> stopNote({required int key, required int sfId}) async {
    if (!loadedSoundfonts.value.containsKey(sfId)) return;
    await midiPro.stopNote(channel: 0, key: key, sfId: sfId);
  }

  void _startGame() {
    if (selectedSfId.value == null || !mounted) return;

    setState(() {
      isPlaying = true;
      final notes = difficulty == 'easy' ? easyNotes : hardNotes;
      final midiNotes = notes.map(_noteNameToMidi).toList();
      randomNote = midiNotes[Random().nextInt(midiNotes.length)];
      _generateOptions();
    });

    playNote(key: randomNote!, sfId: selectedSfId.value!);

    var delayedOp = Future.delayed(const Duration(seconds: 1), () {
      if (mounted && selectedSfId.value != null && randomNote != null) {
        stopNote(key: randomNote!, sfId: selectedSfId.value!);
      }
    });
    _pendingOperations.add(delayedOp);
  }

  void _generateOptions() {
    options.clear();
    options.addAll(difficulty == 'easy' ? easyNotes : hardNotes);
  }

  int _noteNameToMidi(String note) {
    const base = 60;
    final noteMap = {
      'C': 0,
      'C#': 1,
      'D': 2,
      'D#': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'G': 7,
      'G#': 8,
      'A': 9,
      'A#': 10,
      'B': 11,
    };
    return base + (noteMap[note] ?? 0);
  }

  String _midiToNoteName(int midi) {
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    int noteIndex = midi % 12;
    return noteNames[noteIndex];
  }

  void _checkAnswer(String selectedOption) {
    if (!mounted) return;

    if (_auth.getCurrentUser() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    String correctAnswer = _midiToNoteName(randomNote!);
    bool isCorrect = selectedOption == correctAnswer;
    setState(() {
      if (isCorrect) {
        score++;
        totalAttempts++;
        if (score > highScore) highScore = score;
      } else {
        totalAttempts++;
        score = 0;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCorrect ? "Đúng rồi!" : "Sai rồi! Đáp án đúng là $correctAnswer",
            style: TextStyle(
              fontSize: 16,
              color: isCorrect ? Colors.green : Colors.red,
            ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    Future.delayed(const Duration(milliseconds: 800), _startGame);
  }

  void _onDifficultyChanged(String? value) {
    if (value == null) return;
    setState(() {
      difficulty = value;
      score = 0;
      totalAttempts = 0;
    });
    _startGame();
  }

  void _endQuiz() async {
    if (!mounted) return;

    if (_auth.getCurrentUser() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    print('Điểm mới nhất là: $highScore');
    await _auth.updateHighScore('ear_training', highScore);
    int newHighScore = await _auth.getHighScore('ear_training');
    if (mounted) {
      setState(() {
        highScore = newHighScore;
      });
    }

    if (mounted) {
      setState(() {
        isPlaying = false;
        score = 0;
        totalAttempts = 0;
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Luyện Cảm Âm',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: selectedSfId,
        builder: (context, selectedSfIdValue, child) {
          if (selectedSfIdValue == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                      onSelected: (selected) => _onDifficultyChanged('easy'),
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
                      onSelected: (selected) => _onDifficultyChanged('hard'),
                      selectedColor: Colors.redAccent,
                      backgroundColor: Colors.grey[700],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  color: Colors.blueGrey[800],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18.0,
                      horizontal: 24,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Điểm: $score / $totalAttempts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Điểm cao nhất: $highScore',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    if (mounted && randomNote != null) {
                      playNote(key: randomNote!, sfId: selectedSfIdValue);
                      var delayedOp = Future.delayed(
                        const Duration(seconds: 1),
                        () {
                          if (mounted && randomNote != null) {
                            stopNote(key: randomNote!, sfId: selectedSfIdValue);
                          }
                        },
                      );
                      _pendingOperations.add(delayedOp);
                    }
                  },
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                  label: const Text(
                    'Nghe lại',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Chọn nốt nhạc',
                  style: TextStyle(
                    color: Colors.orange[200],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: difficulty == 'easy' ? 4 : 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children:
                      options.map((option) {
                        return ElevatedButton(
                          onPressed: () => _checkAnswer(option),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: Text(option),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _endQuiz,
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: const Text(
                    "Thoát trò chơi",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    if (selectedSfId.value != null && randomNote != null) {
      stopNote(key: randomNote!, sfId: selectedSfId.value!);
    }

    if (selectedSfId.value != null) {
      midiPro.unloadSoundfont(selectedSfId.value!);
    }

    super.dispose();
  }
}
