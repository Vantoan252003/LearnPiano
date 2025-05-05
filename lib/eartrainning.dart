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
      randomNote = 48 + Random().nextInt(24);
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
    options.addAll(noteNames);
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
    if (selectedOption == correctAnswer) {
      setState(() {
        score++;
        totalAttempts++;
        if (score > highScore) {
          highScore = score;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Đúng rồi!",
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      setState(() {
        totalAttempts++;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Sai rồi! Đáp án đúng là $correctAnswer",
              style: TextStyle(color: Colors.red, fontSize: 15),
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
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
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: selectedSfId,
        builder: (context, selectedSfIdValue, child) {
          if (selectedSfIdValue == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Điểm: $score / $totalAttempts đúng',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  Text(
                    'Điểm cao nhất: $highScore',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted &&
                          selectedSfIdValue != null &&
                          randomNote != null) {
                        playNote(key: randomNote!, sfId: selectedSfIdValue);
                        var delayedOp = Future.delayed(
                          const Duration(seconds: 1),
                          () {
                            if (mounted &&
                                selectedSfIdValue != null &&
                                randomNote != null) {
                              stopNote(
                                key: randomNote!,
                                sfId: selectedSfIdValue,
                              );
                            }
                          },
                        );
                        _pendingOperations.add(delayedOp);
                      }
                    },
                    child: Text(
                      "Nghe lại",
                      style: TextStyle(fontSize: 20, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chọn nốt nhạc",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3,
                    children:
                        options.map((option) {
                          return ElevatedButton(
                            onPressed: () => _checkAnswer(option),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(option),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _endQuiz,
                      child: const Text("Thoát trò chơi"),
                    ),
                  ),
                ],
              ),
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

  Widget _buildNoteRow(String note, String? alternative) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            color: Colors.blue,
            child: Text(
              note,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          if (alternative != null) ...[
            const SizedBox(width: 10),
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              color: Colors.grey,
              child: Text(
                alternative,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
