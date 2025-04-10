import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
class EarTrainning extends StatefulWidget {
  const EarTrainning({super.key});
  @override
  State<EarTrainning> createState() => _EarTrainningState();
}

class _EarTrainningState extends State<EarTrainning> {
  final MidiPro midiPro = MidiPro();
  final ValueNotifier<Map<int, String>> loadedSoundfonts = ValueNotifier<Map<int, String>>({});
  final ValueNotifier<int?> selectedSfId = ValueNotifier<int?>(null);

  int? randomNote; // Nốt ngẫu nhiên được phát
  int score = 0; // Điểm số
  int totalAttempts = 0; // Tổng số lần thử
  bool isPlaying = false; // Trạng thái trò chơi
  List<String> options = []; // Các lựa chọn trả lời
  Map<String, String> noteAlternatives = {
    'A#': 'Bb',
    'C#': 'Db',
    'D#': 'Eb',
    'F#': 'Gb',
    'G#': 'Ab',
  };

  @override
  void initState() {
    super.initState();
    _loadDefaultSoundfont();
  }

  Future<void> _loadDefaultSoundfont() async {
    final int sfId = await loadSoundfont('assets/Grand_Piano.sf2');
    selectedSfId.value = sfId;
    _startGame();
  }

  Future<int> loadSoundfont(String path) async {
    if (loadedSoundfonts.value.containsValue(path)) {
      return loadedSoundfonts.value.entries.firstWhere((element) => element.value == path).key;
    }
    final int sfId = await midiPro.loadSoundfont(path: path, bank: 0, program: 0);
    loadedSoundfonts.value = {sfId: path, ...loadedSoundfonts.value};
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
    if (selectedSfId.value == null) return;
    setState(() {
      isPlaying = true;
      randomNote = 48 + Random().nextInt(24);
      _generateOptions();
      playNote(key: randomNote!, sfId: selectedSfId.value!);
      Future.delayed(const Duration(seconds: 1), () {
        stopNote(key: randomNote!, sfId: selectedSfId.value!);
      });
    });
  }

  void _generateOptions() {
    options.clear();
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    options.addAll(noteNames);
  }

  String _midiToNoteName(int midi) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    int noteIndex = midi % 12;
    return noteNames[noteIndex];
  }

  void _checkAnswer(String selectedOption) {
    String correctAnswer = _midiToNoteName(randomNote!);
    if (selectedOption == correctAnswer) {
      setState(() {
        score++;
        totalAttempts++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Đúng rồi!",
            style: TextStyle(fontSize: 16, color: Colors.green),
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      totalAttempts++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sai rồi! Đáp án đúng là $correctAnswer", style: TextStyle(color: Colors.red, fontSize: 15),),
          duration: Duration(seconds: 1),
        ),
      );
    }
    Future.delayed(const Duration(seconds: 0), () {
      _startGame();
    });
  }

  void _endQuiz() {
    setState(() {
      isPlaying = false;
      score = 0;
      totalAttempts = 0;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Luyện Cảm Âm', style: TextStyle(color: Colors.white)),
      ),
      body:
      ValueListenableBuilder(

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
                    '$score trên $totalAttempts đúng ',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      playNote(key: randomNote!, sfId: selectedSfIdValue);
                      Future.delayed(const Duration(seconds: 1), () {
                        stopNote(key: randomNote!, sfId: selectedSfIdValue);
                      });
                    },
                    child: Text("Nghe lại", style: TextStyle(fontSize: 20, color: Colors.black),),
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
                    children: options.map((option) {
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