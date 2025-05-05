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
  ];
  String? currentNote;
  int score = 0;
  int highScore = 0;
  String? selectedNote;
  final Random random = Random();

  // Map to handle enharmonic equivalents (notes that sound the same but are written differently)
  // Cập nhật chính xác các tương đương enharmonic
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
          highScore = doc.data()?['highScore'] ?? 0;
        });
      }
    }
  }

  void _saveHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && score > highScore) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'highScore': score,
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
          "Nhận diện nốt nhạc",
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
              child: CustomPaint(painter: StaffAndNotePainter(currentNote)),
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

class StaffAndNotePainter extends CustomPainter {
  final String? note;

  StaffAndNotePainter(this.note);

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
      // Bảng ánh xạ vị trí nốt trên khuông nhạc (Treble Clef)
      // Cập nhật đúng các vị trí của nốt giáng
      final Map<String, double> notePositions = {
        'C': 5.0, // C4 - dưới khuông nhạc, 1 đường phụ
        'C#': 5.0, // C#4 (cùng vị trí với C4, khác dấu hóa)
        'Db': 4.5, // Db4 (tương đương D4, thấp hơn 1 nửa cung)
        'D': 4.5, // D4 - dưới khuông nhạc
        'D#': 4.5, // D#4 (cùng vị trí với D4, khác dấu hóa)
        'Eb': 4.0, // Eb4 (tương đương với E4, thấp hơn 1 nửa cung)
        'E': 4.0, // E4
        'Fb': 3.5, // Fb4 (tương đương với F4, thấp hơn 1 nửa cung)
        'F': 3.5, // F4 - khoảng trống đầu tiên
        'F#': 3.5, // F#4 (cùng vị trí với F4, khác dấu hóa)
        'Gb': 3.0, // Gb4 (tương đương với G4, thấp hơn 1 nửa cung)
        'G': 3.0, // G4 - đường kẻ 2
        'G#': 3.0, // G#4 (cùng vị trí với G4, khác dấu hóa)
        'Ab': 2.5, // Ab4 (tương đương với A4, thấp hơn 1 nửa cung)
        'A': 2.5, // A4 - khoảng trống thứ 2
        'A#': 2.5, // A#4 (cùng vị trí với A4, khác dấu hóa)
        'Bb': 2.0, // Bb4 (tương đương với B4, thấp hơn 1 nửa cung)
        'B': 2.0, // B4 - đường kẻ 3
        'Cb': 1.5, // Cb5 (tương đương với C5, thấp hơn 1 nửa cung)
        'C5': 1.5, // C5 - khoảng trống thứ 3
      };

      // Map về tên nốt thực (không phụ thuộc dấu hóa) để vẽ đúng vị trí
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
        'Cb': 'C5',
      };

      // Lấy vị trí nốt nhạc trên khuông nhạc
      final positionIndex = notePositions[note!] ?? 2.0;
      final yPosition = 5 + positionIndex * lineSpacing;

      // Vẽ đường kẻ phụ TRƯỚC KHI vẽ nốt để nốt được hiển thị đè lên đường kẻ
      // Vẽ đường kẻ phụ nếu nốt nằm ngoài khuông
      if (positionIndex >= 4.0 || positionIndex <= 1.0) {
        // Xác định các đường kẻ phụ cần vẽ
        List<double> auxiliaryLines = [];

        // Nếu nốt nằm dưới khuông nhạc (C4, D4)
        if (positionIndex >= 4.0) {
          // Với C4, cần đường kẻ phụ tại positionIndex 5.0
          if (positionIndex >= 5.0) {
            auxiliaryLines.add(5.0);
          }
          // Nếu có nốt thấp hơn C4, thêm đường kẻ phụ tiếp theo
          // (Hiện tại chưa cần thiết trong ứng dụng này)

          // Thêm đường kẻ phụ cho các nốt nằm trên dòng kẻ phụ (C4)
          if (positionIndex.round() == positionIndex) {
            auxiliaryLines.add(positionIndex);
          }
        }

        // Nếu nốt nằm trên khuông nhạc (B5, C5 và cao hơn)
        if (positionIndex <= 1.0) {
          // Với C5, cần đường kẻ phụ tại positionIndex 1.0
          if (positionIndex <= 1.0) {
            auxiliaryLines.add(1.0);
          }
          // Nếu có nốt cao hơn C5, thêm đường kẻ phụ tiếp theo
          // (Hiện tại chưa cần thiết trong ứng dụng này)

          // Thêm đường kẻ phụ cho các nốt nằm trên dòng kẻ phụ
          if (positionIndex.round() == positionIndex) {
            auxiliaryLines.add(positionIndex);
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

      // Vẽ chỉ dấu thăng (#) hoặc giáng (b) bên trái nốt
      if (note!.contains('#') || note!.contains('b')) {
        TextPainter(
            text: TextSpan(
              text:
                  note!.contains('#')
                      ? '\u{266F}'
                      : '\u{266D}', // Chỉ vẽ dấu thăng hoặc giáng
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
