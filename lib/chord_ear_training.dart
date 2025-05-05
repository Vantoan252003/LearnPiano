import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

class ChordTraining extends StatefulWidget {
  const ChordTraining({super.key});
  @override
  State<ChordTraining> createState() => _ChordTrainingState();
}

class _ChordTrainingState extends State<ChordTraining> {
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
          highScore = doc.data()?['chordHighScore'] ?? 0;
        });
      }
    }
  }

  void _saveHighScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && score > highScore) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'chordHighScore': score,
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
          "Đoán hợp âm",
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
                    Container(
                      height: 150,
                      width: 450,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      child: CustomPaint(
                        painter: ChordStaffPainter(
                          rootNote: currentRootNote ?? 'C',
                          chordType: currentChordType ?? 'Major',
                          showChordName: showAnswer,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _playChord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        "Phát âm thanh",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
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

class ChordStaffPainter extends CustomPainter {
  final String rootNote;
  final String chordType;
  final bool showChordName;

  ChordStaffPainter({
    required this.rootNote,
    required this.chordType,
    this.showChordName = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

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

    final chordSymbols = {'Major': '', 'Minor': 'm', 'Dim': '°', 'Aug': '+'};

    if (showChordName) {
      final chordText = '$rootNote${chordSymbols[chordType]}';
      TextPainter(
          text: TextSpan(
            text: 'Đáp án đúng là:  $chordText',
            style: const TextStyle(
              fontSize: 30,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(size.width / 2 - 110, size.height - 230));
    }

    _drawChordNotes(canvas, size, lineSpacing);
  }

  void _drawChordNotes(Canvas canvas, Size size, double lineSpacing) {
    final Map<String, double> notePositions = {
      'C': 5.0,
      'C#': 5.0,
      'D': 4.5,
      'D#': 4.5,
      'E': 4.0,
      'F': 3.5,
      'F#': 3.5,
      'G': 3.0,
      'G#': 3.0,
      'A': 2.5,
      'A#': 2.5,
      'B': 2.0,
    };

    final intervals =
        {
          'Major': [0, 4, 7],
          'Minor': [0, 3, 7],
          'Dim': [0, 3, 6],
          'Aug': [0, 4, 8],
        }[chordType] ??
        [0, 4, 7];

    final noteIndices = {
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
    ];
    final rootIndex = noteIndices[rootNote] ?? 0;

    for (int i = 0; i < intervals.length; i++) {
      final noteIndex = (rootIndex + intervals[i]) % 12;
      final note = notes[noteIndex];

      final position = notePositions[note] ?? 3.0;
      final yPosition = 5 + position * lineSpacing;

      final xOffset = i * 40;
      final xPosition = size.width / 2 - 20 + xOffset;

      if (position >= 4.0 || position <= 1.0) {
        List<double> auxiliaryLines = [];

        if (position >= 4.0) {
          if (position >= 5.0) {
            auxiliaryLines.add(5.0);
          }
          if (position.round() == position) {
            auxiliaryLines.add(position);
          }
        }

        if (position <= 1.0) {
          if (position <= 1.0) {
            auxiliaryLines.add(1.0);
          }
          if (position.round() == position) {
            auxiliaryLines.add(position);
          }
        }

        for (double linePos in auxiliaryLines) {
          double lineYPosition = 5 + linePos * lineSpacing;
          canvas.drawLine(
            Offset(xPosition - 20, lineYPosition),
            Offset(xPosition + 20, lineYPosition),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1.5,
          );
        }
      }

      final notePaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(xPosition, yPosition),
          width: 30,
          height: 25,
        ),
        notePaint,
      );

      if (note.contains('#')) {
        TextPainter(
            text: const TextSpan(
              text: '\u{266F}',
              style: TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )
          ..layout()
          ..paint(canvas, Offset(xPosition - 45, yPosition - 38));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
