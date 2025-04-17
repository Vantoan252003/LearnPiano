import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:learn_piano/auth_service.dart';
import 'package:learn_piano/login_screen.dart';

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
  final AuthService _auth = AuthService();
  String? currentTargetNote;
  int score = 0;
  int highScore = 0;
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

  void handleTap(String note) async {
    if (_auth.getCurrentUser() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    if (!isGameActive) return;
    if (note == currentTargetNote) {
      setState(() {
        score++;
        playSound(note);
        generateNewTarget();
        if (score > highScore) {
          highScore = score;
        }
      });
    } else {
      setState(() {
        isGameActive = false;
      });
      try {
        print('Game over, current high score: $highScore');
        await _auth.updateHighScore('piano_challenge', highScore);
        int newHighScore = await _auth.getHighScore('piano_challenge');
        print('New high score from Firestore: $newHighScore');
        setState(() {
          highScore = newHighScore;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu điểm: $e')),
        );
      }
      showGameOverDialog();
    }
  }

  void resetGame() async {
    if (_auth.getCurrentUser() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    setState(() {
      score = 0;
      isGameActive = true;
      generateNewTarget();
    });
    try {
      int score = await _auth.getHighScore('piano_challenge');
      setState(() {
        highScore = score;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải điểm số: $e')),
      );
    }
  }

  void showGameOverDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Trò chơi kết thúc"),
          content: Text("Điểm của bạn: $score\nĐiểm cao nhất: $highScore"),
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
    _checkLoginAndLoad();
  }

  Future<void> _checkLoginAndLoad() async {
    if (_auth.getCurrentUser() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    print('User logged in: ${_auth.getCurrentUser()?.uid}');
    try {
      int score = await _auth.getHighScore('piano_challenge');
      setState(() {
        highScore = score;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải điểm số: $e')),
      );
    }
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
        elevation: 0,
        title: const Text(
          "Nhận diện phím đàn",
          style: TextStyle(color: Colors.white, fontSize: 30),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(60),
              color: Colors.grey[900],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.music_note,
                          size: 30,
                          color: Colors.white,
                        ),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                            children: [
                              const TextSpan(
                                text: "Nhấn phím: ",
                                style: TextStyle(color: Colors.white),
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
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      "Điểm cao nhất: $highScore",
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
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
                  top: 3,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: List.generate(whiteNotes.length, (index) {
                      if (index == 0 || index == 1 || index == 3 || index == 4 || index == 5) {
                        final blackNoteIndex = index == 0
                            ? 0
                            : index == 1
                            ? 1
                            : index == 3
                            ? 2
                            : index == 4
                            ? 3
                            : 4;
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