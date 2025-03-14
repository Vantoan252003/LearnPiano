import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class PianoChallenge extends StatefulWidget {
  const PianoChallenge({super.key});

  @override
  State<PianoChallenge> createState() => _PianoChallengeState();
}

class _PianoChallengeState extends State<PianoChallenge> {
  final List<String> whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final List<Color> colors = [
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
  ];
  final List<String> blackNotes = ['C#', 'D#', 'F#', 'G#', 'A#'];
  final AudioPlayer audioPlayer = AudioPlayer();
  String? currentTargetNote;
  int score = 0;
  bool isGameActive = true;

  void playSound(String note) async {
    try {
      if (note.isNotEmpty) {
        await audioPlayer.play(AssetSource('sounds/$note.mp3'));
        print('Playing sound: sounds/$note.mp3');
      }
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void generateNewTarget() {
    final random = Random();
    setState(() {
      currentTargetNote = whiteNotes[random.nextInt(whiteNotes.length)];
    });
  }

  void handleTap(String note) {
    if (!isGameActive) return;
    if (note == currentTargetNote) {
      setState(() {
        score++;
        playSound(note);
        generateNewTarget();
      });
    } else {
      setState(() {
        isGameActive = false;
      });
      showGameOverDialog();
    }
  }

  void resetGame() {
    setState(() {
      score = 0;
      isGameActive = true;
      generateNewTarget();
    });
  }

  void showGameOverDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Trò chơi kết thúc"),
          content: Text("Điểm của bạn là: $score"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                resetGame();
              },
              child: const Text("Chơi lại"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    generateNewTarget();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Đoán phím đàn: ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note, size: 30),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                            children: [
                              const TextSpan(
                                text: "Nhấn phím: ",
                                style: TextStyle(color: Colors.black),
                              ),
                              TextSpan(
                                text: "$currentTargetNote",
                                style: const TextStyle(color: Colors.indigoAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Điểm: $score",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                Positioned(
                  top: 150,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    children: List.generate(whiteNotes.length, (index) {
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => handleTap(whiteNotes[index]),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0),
                            decoration: BoxDecoration(
                              color: colors[index],
                              border: Border.all(color: Colors.black, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned(
                  top: 150,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: List.generate(whiteNotes.length, (index) {
                      if (index == 0 || index == 1 || index == 3 || index == 4 || index == 5) {
                        final blackNoteIndex = index == 0 ? 0 : index == 1 ? 1 : index == 3 ? 2 : index == 4 ? 3 : 4;
                        return Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Transform.translate(
                              offset: const Offset(30, 0),
                              child: GestureDetector(
                                onTap: () => handleTap(blackNotes[blackNoteIndex]),
                                child: Container(
                                  width: 40,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return const Expanded(child: SizedBox());
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}