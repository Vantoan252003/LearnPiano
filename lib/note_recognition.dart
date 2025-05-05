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
          content: Text("Đúng! +1 điểm", style: TextStyle(fontSize: 16)),
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
          "Nhận diện nốt nhạc",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 150,
              width: 450,
              child: CustomPaint(
                painter: StaffAndNotePainter(currentNote),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Điểm: $score",
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              "Điểm cao nhất: $highScore",
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
            const SizedBox(height: 30),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              padding: const EdgeInsets.all(12),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: Text(
                    note,
                    style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
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
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Vẽ 5 đường kẻ khuông nhạc
    double lineSpacing = (size.height - 40) / 4;
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(20, 5 + i * lineSpacing),
        Offset(size.width - 20, 5 + i * lineSpacing),
        paint,
      );
    }

    // Vẽ khóa Sol (Treble Clef) bằng Text
    TextPainter(
      text: const TextSpan(
        text: '\u{1D11E}',
        style: TextStyle(
          fontFamily: 'MusicalSymbols',
          fontSize: 105,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, Offset(20, 5 + lineSpacing - 30));

    // Vẽ nốt nhạc
    if (note != null) {
      // Bảng ánh xạ vị trí nốt trên khuông nhạc (Treble Clef, từ C4 đến B4)
      final Map<String, double> notePositions = {
        'C': 4.0,   // C4
        'C#': 4.0,
        'Db': 4.0,
        'D': 3.5,
        'D#': 3.5,
        'Eb': 3.5,
        'E': 3.0,   // Đường kẻ 1
        'F': 2.5,
        'F#': 2.5,
        'Gb': 2.5,
        'G': 2.0,   // Đường kẻ 2
        'G#': 2.0,
        'Ab': 2.0,
        'A': 1.5,
        'A#': 1.5,
        'Bb': 1.5,
        'B': 1.0,   // Đường kẻ 3
        'Cb': 4.0,  // Sửa thành cùng vị trí với C4
        // Thêm nốt cao hơn nếu cần
        'C5': 0.0,  // Trên đường kẻ 5
      };

      final positionIndex = notePositions[note!] ?? 2.0;
      final yPosition = 5 + positionIndex * lineSpacing;

      // Vẽ nốt (hình elip)
      final notePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, yPosition),
          width: 30,
          height: 20,
        ),
        notePaint,
      );

      // Vẽ chỉ dấu thăng (#) hoặc giáng (b) bên phải nốt
      if (note!.contains('#') || note!.contains('b')) {
        TextPainter(
          text: TextSpan(
            text: note!.contains('#') ? '\u{266F}' : '\u{266D}', // Chỉ vẽ dấu thăng hoặc giáng
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
          ..layout()
          ..paint(canvas, Offset(size.width / 2 - 40, yPosition - 34));
      }

      // Vẽ đường kẻ phụ nếu nốt nằm ngoài khuông
      if (positionIndex >= 4.0) {
        canvas.drawLine(
          Offset(size.width / 2 - 20, 5 + 4 * lineSpacing),
          Offset(size.width / 2 + 20, 5 + 4 * lineSpacing),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}