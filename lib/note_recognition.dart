import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoteRecognition extends StatefulWidget {
  const NoteRecognition({super.key});

  @override
  _NoteRecognitionState createState() => _NoteRecognitionState();
}

class _NoteRecognitionState extends State<NoteRecognition> {
  final List<String> notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    'Cb', 'Db', 'Eb', 'Fb', 'Gb', 'Ab', 'Bb'];
  String? currentNote;
  int score = 0;
  int highScore = 0;
  String? selectedNote;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _generateNewNote();
    _loadHighScore();
  }

  void _generateNewNote() {
    setState(() {
      currentNote = notes[random.nextInt(notes.length)];
      selectedNote = null;
    });
  }

  void _loadHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          highScore = doc.data()?['highScore'] ?? 0;
        });
      }
    }
  }

  void _saveHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && score > highScore) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'highScore': score}, SetOptions(merge: true));
      setState(() {
        highScore = score;
      });
    }
  }

  void _checkAnswer() {
    if (selectedNote == currentNote) {
      setState(() {
        score++;
        _saveHighScore();
        _generateNewNote();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đúng! +1 điểm"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      setState(() {
        if (score > 0) score--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sai! -1 điểm"),
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
          "Nhận diện nốt nhạc",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 150,
              width: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
              ),
              child: CustomPaint(
                painter: StaffAndNotePainter(currentNote),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Điểm: $score",
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            Text(
              "Điểm cao nhất: $highScore",
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              padding: const EdgeInsets.all(10),
              children: notes.map((note) {
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedNote = note;
                    });
                    _checkAnswer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedNote == note
                        ? (selectedNote == currentNote ? Colors.green : Colors.red)
                        : Colors.grey[300],
                  ),
                  child: Text(
                    note,
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffAndNotePainter extends CustomPainter {
  final String? note;

  StaffAndNotePainter(this.note);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    // Vẽ 5 đường kẻ khuông nhạc
    double lineSpacing = size.height / 5; // Chia đều cho 5 đường kẻ
    for (int i = 0; i < 5; i++) { // Chỉ vẽ 5 đường
      canvas.drawLine(
        Offset(0, i * lineSpacing),
        Offset(size.width, i * lineSpacing),
        paint,
      );
    }

    // Vẽ khóa Sol (Treble Clef) bằng Text
    TextPainter(
      text: const TextSpan(
        text: '\u{1D11E}', // Unicode của khóa Sol
        style: TextStyle(
          fontFamily: 'MusicalSymbols',
          fontSize: 80,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, Offset(0, lineSpacing - 20));

    // Vẽ nốt nhạc
    if (note != null) {
      // Bảng ánh xạ vị trí nốt trên khuông nhạc (Treble Clef, từ C4 đến B4)
      final Map<String, double> notePositions = {
        'C': 5.0,  // Đường kẻ phụ dưới
        'C#': 5.0,
        'Db': 5.0,
        'D': 4.5,
        'D#': 4.5,
        'Eb': 4.5,
        'E': 4.0,  // Đường kẻ 1
        'F': 3.5,
        'F#': 3.5,
        'Gb': 3.5,
        'G': 3.0,  // Đường kẻ 2
        'G#': 3.0,
        'Ab': 3.0,
        'A': 2.5,
        'A#': 2.5,
        'Bb': 2.5,
        'B': 2.0,  // Đường kẻ 3
        'Cb': 2.0,
      };

      final positionIndex = notePositions[note!] ?? 3.0;
      final yPosition = positionIndex * lineSpacing;

      // Vẽ dấu thăng/giáng nếu có
      if (note!.contains('#') || note!.contains('b')) {
        TextPainter(
          text: TextSpan(
            text: note!.contains('#') ? '\u{266F}' : '\u{266D}', // Dấu thăng hoặc giáng
            style: const TextStyle(
              fontSize: 40, // Tăng kích thước để rõ hơn
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
          ..layout()
          ..paint(canvas, Offset(size.width / 2 - 40, yPosition - 20)); // Điều chỉnh vị trí
      }

      // Vẽ nốt (hình elip)
      final notePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, yPosition),
          width: 14,
          height: 10,
        ),
        notePaint,
      );

      // Vẽ đường kẻ phụ nếu nốt nằm ngoài khuông
      if (positionIndex >= 5.0) {
        canvas.drawLine(
          Offset(size.width / 2 - 20, 4 * lineSpacing),
          Offset(size.width / 2 + 20, 4 * lineSpacing),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}