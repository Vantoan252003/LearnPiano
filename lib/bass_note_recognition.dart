import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BassNoteRecognition extends StatefulWidget {
  const BassNoteRecognition({super.key});

  @override
  _BassNoteRecognitionState createState() => _BassNoteRecognitionState();
}

class _BassNoteRecognitionState extends State<BassNoteRecognition> {
  final List<String> notes = [
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
    'Cb',
    'Db',
    'Eb',
    'Fb',
    'Gb',
    'Ab',
    'Bb',
    'B#',
  ];
  String? currentNote;
  int score = 0;
  int highScore = 0;
  String? selectedNote;
  final Random random = Random();

  // Map để xử lý các nốt tương đương enharmonic (các nốt có âm thanh giống nhau nhưng được viết khác nhau)
  final Map<String, List<String>> enharmonicEquivalents = {
    'B': ['Cb'],
    'C': [],
    'C#': ['Db'],
    'D': [],
    'D#': ['Eb'],
    'E': ['Fb'],
    'F': [],
    'F#': ['Gb'],
    'G': [],
    'G#': ['Ab'],
    'A': [],
    'A#': ['Bb'],
    'Cb': ['B'],
    'Db': ['C#'],
    'Eb': ['D#'],
    'Fb': ['E'],
    'Gb': ['F#'],
    'Ab': ['G#'],
    'Bb': ['A#'],
    'B#': ['C'],
  };

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
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          highScore =
              doc.data()?['bassHighScore'] ??
              0; // Sử dụng bassHighScore thay vì highScore
        });
      }
    }
  }

  void _saveHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && score > highScore) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'bassHighScore': score, // Lưu điểm cao nhất cho khóa Fa
      }, SetOptions(merge: true));
      setState(() {
        highScore = score;
      });
    }
  }

  // Kiểm tra xem hai nốt có tương đương enharmonic không
  bool _areEnharmonicEquivalents(String? note1, String? note2) {
    if (note1 == null || note2 == null) return false;
    if (note1 == note2) return true;

    // Kiểm tra theo cả hai chiều để đảm bảo hoạt động chính xác
    if (enharmonicEquivalents.containsKey(note1)) {
      if (enharmonicEquivalents[note1]!.contains(note2)) {
        return true;
      }
    }

    if (enharmonicEquivalents.containsKey(note2)) {
      if (enharmonicEquivalents[note2]!.contains(note1)) {
        return true;
      }
    }

    return false;
  }

  void _checkAnswer() {
    if (selectedNote == currentNote ||
        _areEnharmonicEquivalents(selectedNote, currentNote)) {
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
          "Nhận diện nốt nhạc - Khóa Fa",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 150,
              width: 450,
              child: CustomPaint(painter: BassStaffAndNotePainter(currentNote)),
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
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
            const SizedBox(height: 30),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              padding: const EdgeInsets.all(12),
              children:
                  notes.map((note) {
                    return ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedNote = note;
                        });
                        _checkAnswer();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selectedNote == note
                                ? (selectedNote == currentNote
                                    ? Colors.green
                                    : Colors.red)
                                : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: Text(
                        note,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

class BassStaffAndNotePainter extends CustomPainter {
  final String? note;

  BassStaffAndNotePainter(this.note);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
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
    TextPainter(
        text: const TextSpan(
          text: '\u{1D122}',
          style: TextStyle(
            fontFamily: 'MusicalSymbols',
            fontSize: 80,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(20, 5 + 2 * lineSpacing - 60));
    // Vẽ nốt nhạc
    if (note != null) {
      final Map<String, double> notePositions = {
        'C': 2.5, // C3 - dòng kẻ 3
        'C#': 2.5, // đúng
        'Db': 2.0, //đã đúng
        'D': 2.0, // đã đúng
        'D#': 2.0, // đã đúng
        'Eb': 1.5, // Eb3 (tương đương E3)
        'E': 1.5, // đã sửa
        'Fb': 1, //đã đúng
        'F': 1.0,
        'F#': 1.0, // đã đúng
        'Gb': 0.5, //đã đúng
        'G': 0.5, // đã đúng
        'G#': 0.5, // đã đúng
        'Ab': -0, //đúng
        'A': 0, // đã đúng
        'A#': -0.5, //đúng
        'Bb': -0.5, // đã sửa
        'B': -0.5, // B3 - trên khuông nhạc, cần đường kẻ phụ
        'Cb': -1.0, // Cb3 (tương đương B3)
        'B#': -0.5,
      };

      // Map tên nốt thực (không phụ thuộc dấu hóa)
      final Map<String, String> realNoteNames = {
        'C': 'C',
        'C#': 'C',
        'Db': 'D',
        'D': 'D',
        'D#': 'D',
        'Eb': 'E',
        'E': 'E',
        'Fb': 'F',
        'F': 'F',
        'F#': 'F',
        'Gb': 'G',
        'G': 'G',
        'G#': 'G',
        'Ab': 'A',
        'A': 'A',
        'A#': 'A',
        'Bb': 'B',
        'B': 'B',
        'Cb': 'C4',
        'B#': 'C',
      };

      // Lấy vị trí nốt nhạc trên khuông nhạc
      final positionIndex = notePositions[note!] ?? 2.0;
      final yPosition = 5 + positionIndex * lineSpacing;

      if (positionIndex > 4.0 || positionIndex < 0.0) {
        // Xác định các đường kẻ phụ cần vẽ
        List<double> auxiliaryLines = [];

        // Nếu nốt nằm dưới khuông nhạc (dưới G2)
        if (positionIndex > 4.0) {
          // Thêm đường kẻ phụ cho các nốt dưới khuông nhạc
          for (double i = 5.0; i <= positionIndex; i += 1.0) {
            if (i.round() == i) {
              auxiliaryLines.add(i);
            }
          }
        }

        // Nếu nốt nằm trên khuông nhạc (trên G3)
        if (positionIndex < 0.0) {
          // Thêm đường kẻ phụ cho các nốt trên khuông nhạc
          for (double i = 0.0; i >= positionIndex; i -= 1.0) {
            if (i.round() == i) {
              auxiliaryLines.add(i);
            }
          }
        }

        // Vẽ các đường kẻ phụ
        for (double linePos in auxiliaryLines) {
          double lineYPosition = 5 + linePos * lineSpacing;
          canvas.drawLine(
            Offset(size.width / 2 - 20, lineYPosition),
            Offset(size.width / 2 + 20, lineYPosition),
            paint,
          );
        }
      }

      // Vẽ nốt (hình elip)
      final notePaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, yPosition),
          width: 30,
          height: 25,
        ),
        notePaint,
      );

      // Vẽ dấu thăng (#) hoặc giáng (b) bên trái nốt
      if (note!.contains('#') || note!.contains('b')) {
        TextPainter(
            text: TextSpan(
              text: note!.contains('#') ? '\u{266F}' : '\u{266D}',
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )
          ..layout()
          ..paint(canvas, Offset(size.width / 2 - 45, yPosition - 38));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
