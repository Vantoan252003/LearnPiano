import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

class ChordWithoutSheet extends StatefulWidget {
  const ChordWithoutSheet({super.key});
  @override
  State<ChordWithoutSheet> createState() => _ChordWithoutSheetState();
}

class _ChordWithoutSheetState extends State<ChordWithoutSheet> {
  final List<String> rootNotes = [
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
  final List<String> chordTypes = ['Major', 'Minor', 'Aug', 'Dim'];
  final Map<String, List<int>> chordIntervals = {
    'Major': [0, 4, 7],
    'Minor': [0, 3, 7],
    'Dim': [0, 3, 6],
    'Aug': [0, 4, 8],
  };
  final MidiPro midiPro = MidiPro();
  int? soundfontId;
  bool isLoading = true;
  bool showAnswer = false;
  String? currentRootNote;
  String? currentChordType;
  String? selectedChordType;
  int score = 0;
  int highScore = 0;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _loadSoundfont();
    _generateNewChord();
    _loadHighScore();
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
  }

  void _generateNewChord() {
    setState(() {
      currentRootNote = rootNotes[random.nextInt(rootNotes.length)];
      currentChordType = chordTypes[random.nextInt(chordTypes.length)];
      selectedChordType = null;
      showAnswer = false;
    });
  }

  void _loadHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          highScore = doc.data()?['chordNoSheetHighScore'] ?? 0;
        });
      }
    }
  }

  void _saveHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && score > highScore) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'chordNoSheetHighScore': score,
      }, SetOptions(merge: true));
      setState(() {
        highScore = score;
      });
    }
  }

  Future<void> _playChord() async {
    if (soundfontId == null ||
        currentRootNote == null ||
        currentChordType == null)
      return;
    final noteIndices = {
      'C': 60,
      'C#': 61,
      'D': 62,
      'D#': 63,
      'E': 64,
      'F': 65,
      'F#': 66,
      'G': 67,
      'G#': 68,
      'A': 69,
      'A#': 70,
      'B': 71,
    };
    final rootMidi = noteIndices[currentRootNote] ?? 60;
    final intervals = chordIntervals[currentChordType] ?? [0, 4, 7];
    for (var interval in intervals) {
      final noteMidi = rootMidi + interval;
      await midiPro.playNote(
        channel: 0,
        key: noteMidi,
        velocity: 100,
        sfId: soundfontId!,
      );
    }
    Future.delayed(const Duration(milliseconds: 1500), () {
      for (var interval in intervals) {
        final noteMidi = rootMidi + interval;
        midiPro.stopNote(channel: 0, key: noteMidi, sfId: soundfontId!);
      }
    });
  }

  Future<void> _playChordNotesIndividually() async {
    if (soundfontId == null ||
        currentRootNote == null ||
        currentChordType == null)
      return;
    final noteIndices = {
      'C': 60,
      'C#': 61,
      'D': 62,
      'D#': 63,
      'E': 64,
      'F': 65,
      'F#': 66,
      'G': 67,
      'G#': 68,
      'A': 69,
      'A#': 70,
      'B': 71,
    };
    final rootMidi = noteIndices[currentRootNote] ?? 60;
    final intervals = chordIntervals[currentChordType] ?? [0, 4, 7];
    for (var interval in intervals) {
      final noteMidi = rootMidi + interval;
      await midiPro.playNote(
        channel: 0,
        key: noteMidi,
        velocity: 100,
        sfId: soundfontId!,
      );
      await Future.delayed(const Duration(milliseconds: 700));
      midiPro.stopNote(channel: 0, key: noteMidi, sfId: soundfontId!);
    }
  }

  void _checkAnswer(String selected) {
    if (selected == currentChordType) {
      setState(() {
        score++;
        showAnswer = true;
        _saveHighScore();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _generateNewChord();
            _playChord();
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đúng! +1 điểm", style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      setState(() {
        if (score > 0) score--;
        showAnswer = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sai! -1 điểm", style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Đoán hợp âm (Không sheet)",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _playChord,
                      icon: const Icon(Icons.queue_music, color: Colors.white),
                      label: const Text(
                        "Phát hợp âm",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _playChordNotesIndividually,
                      icon: const Icon(Icons.music_note, color: Colors.white),
                      label: const Text(
                        "Phát từng nốt",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      "Điểm: $score",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Điểm cao nhất: $highScore",
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 20,
                      children:
                          chordTypes.map((chordType) {
                            return SizedBox(
                              width: 170,
                              height: 80,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedChordType = chordType;
                                  });
                                  _checkAnswer(chordType);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      selectedChordType == chordType
                                          ? (selectedChordType ==
                                                  currentChordType
                                              ? Colors.green
                                              : Colors.red)
                                          : Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _getChordDisplayName(chordType),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    if (showAnswer)
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Text(
                          'Đáp án đúng: ${currentRootNote ?? ''} ${_getChordDisplayName(currentChordType ?? '')}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  String _getChordDisplayName(String chordType) {
    switch (chordType) {
      case 'Major':
        return 'Trưởng';
      case 'Minor':
        return 'Thứ';
      case 'Dim':
        return 'Dim';
      case 'Aug':
        return 'Aug';
      default:
        return chordType;
    }
  }

  @override
  void dispose() {
    if (soundfontId != null) {
      midiPro.unloadSoundfont(soundfontId!);
    }
    super.dispose();
  }
}
