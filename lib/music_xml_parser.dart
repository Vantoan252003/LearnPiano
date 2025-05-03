import 'package:music_xml/music_xml.dart';
import 'package:xml/xml.dart' as xml;

class MusicXmlParser {
  static Future<List<Map<String, dynamic>>> parseMusicXml(String xmlContent) async {
    final document = MusicXmlDocument.parse(xmlContent);
    final scorePartwise = document.score.getElement('score-partwise');
    if (scorePartwise == null) throw Exception('Invalid MusicXML: No score-partwise found');

    List<Map<String, dynamic>> midiEvents = [];
    double currentTime = 0.0;
    double baseTempo = 120.0;
    int divisions = 1;
    Map<String, int> keySignature = {};
    Map<String, int> measureAccidentals = {};
    List<Map<String, dynamic>> tempMidiEvents = [];
    List<int> repeatStartMeasures = [];
    List<int> repeatEndMeasures = [];
    int measureCount = 0;

    for (var part in scorePartwise.children.whereType<xml.XmlElement>().where((e) => e.name.local == 'part')) {
      for (var measure in part.children.whereType<xml.XmlElement>().where((e) => e.name.local == 'measure')) {
        final direction = measure.getElement('direction');
        if (direction != null) {
          final soundTempo = direction.getElement('sound')?.getAttribute('tempo');
          if (soundTempo != null) {
            baseTempo = double.parse(soundTempo);
            break;
          }
          final metronome = direction.getElement('direction-type')?.getElement('metronome');
          if (metronome != null) {
            final beatUnit = metronome.getElement('beat-unit')?.text;
            final perMinute = metronome.getElement('per-minute')?.text;
            if (beatUnit != null && perMinute != null && beatUnit == 'quarter') {
              baseTempo = double.parse(perMinute);
              break;
            }
          }
        }
      }
      if (baseTempo != 120.0) break;
    }

    for (var part in scorePartwise.children.whereType<xml.XmlElement>().where((e) => e.name.local == 'part')) {
      measureCount = 0;
      for (var measure in part.children.whereType<xml.XmlElement>().where((e) => e.name.local == 'measure')) {
        measureCount++;
        measureAccidentals.clear();
        int noteIndex = 0; // Đếm chỉ số nốt trong mỗi measure

        for (var barline in measure.children.whereType<xml.XmlElement>().where((e) => e.name.local == 'barline')) {
          final repeat = barline.getElement('repeat');
          if (repeat != null) {
            final direction = repeat.getAttribute('direction');
            if (direction == 'forward') {
              repeatStartMeasures.add(measureCount);
            } else if (direction == 'backward') {
              repeatEndMeasures.add(measureCount);
            }
          }
        }

        final attributes = measure.getElement('attributes');
        if (attributes != null) {
          final divisionsElement = attributes.getElement('divisions');
          divisions = divisionsElement != null ? int.parse(divisionsElement.text) : divisions;
          divisions = divisions > 0 ? divisions : 1;

          final keyElement = attributes.getElement('key');
          if (keyElement != null) {
            final fifths = int.parse(keyElement.getElement('fifths')?.text ?? '0');
            keySignature = _getKeySignatureAlterations(fifths);
          }
        }

        final direction = measure.getElement('direction');
        if (direction != null) {
          final soundTempo = direction.getElement('sound')?.getAttribute('tempo');
          if (soundTempo != null) {
            baseTempo = double.parse(soundTempo);
          }
          final metronome = direction.getElement('direction-type')?.getElement('metronome');
          if (metronome != null) {
            final beatUnit = metronome.getElement('beat-unit')?.text;
            final perMinute = metronome.getElement('per-minute')?.text;
            if (beatUnit != null && perMinute != null && beatUnit == 'quarter') {
              baseTempo = double.parse(perMinute);
            }
          }
        }

        List<int> chordNotes = [];
        double chordStartTime = currentTime;
        double chordDuration = 0.0;

        for (var element in measure.children.whereType<xml.XmlElement>()) {
          if (element.name.local == 'note') {
            final pitch = element.getElement('pitch');
            final duration = double.parse(element.getElement('duration')?.text ?? '1');
            final durationInSeconds = (duration / divisions) * (60 / baseTempo);
            bool isFermata = false;
            bool isStaccato = false;
            bool isSlurStart = false;
            bool isSlurEnd = false;

            final notations = element.getElement('notations');
            if (notations != null) {
              if (notations.getElement('fermata') != null) {
                isFermata = true;
              }
              final articulations = notations.getElement('articulations');
              if (articulations?.getElement('staccato') != null) {
                isStaccato = true;
              }
              for (var slur in notations.children.whereType<xml.XmlElement>().where((e) => e.name.local == 'slur')) {
                final type = slur.getAttribute('type');
                if (type == 'start') isSlurStart = true;
                else if (type == 'stop') isSlurEnd = true;
              }
            }

            if (pitch != null) {
              final step = pitch.getElement('step')?.text;
              final octave = int.parse(pitch.getElement('octave')?.text ?? '4');
              final accidental = element.getElement('accidental')?.text;
              final isChord = element.getElement('chord') != null;
              final noteKey = '$step$octave';
              final midiNote = _stepToMidiNote(
                step,
                octave,
                keySignature,
                accidental,
                measureAccidentals,
                noteKey,
              );

              if (midiNote != null) {
                double adjustedDuration = durationInSeconds;
                if (isFermata) {
                  adjustedDuration *= 1.5;
                }
                if (isStaccato) {
                  adjustedDuration *= 0.5;
                }

                if (isChord) {
                  chordNotes.add(midiNote);
                  chordDuration = adjustedDuration;
                } else {
                  if (chordNotes.isNotEmpty) {
                    tempMidiEvents.add({
                      'midiNotes': List<int>.from(chordNotes),
                      'startTime': chordStartTime,
                      'duration': chordDuration,
                      'baseTempo': baseTempo,
                      'isSlurStart': isSlurStart,
                      'isSlurEnd': isSlurEnd,
                      'measure': measureCount,
                      'noteIndex': noteIndex - 1, // Gán noteIndex cho chord trước đó
                    });
                    chordNotes.clear();
                  }
                  chordNotes.add(midiNote);
                  chordStartTime = currentTime;
                  chordDuration = adjustedDuration;
                  noteIndex++; // Tăng chỉ số nốt sau mỗi nốt không phải chord
                }
                if (!isChord) currentTime += durationInSeconds;
              }
            } else {
              currentTime += durationInSeconds;
            }
          } else if (element.name.local == 'forward') {
            final duration = double.parse(element.getElement('duration')?.text ?? '0');
            currentTime += (duration / divisions) * (60 / baseTempo);
          } else if (element.name.local == 'backup') {
            final duration = double.parse(element.getElement('duration')?.text ?? '0');
            currentTime -= (duration / divisions) * (60 / baseTempo);
          }
        }

        if (chordNotes.isNotEmpty) {
          tempMidiEvents.add({
            'midiNotes': List<int>.from(chordNotes),
            'startTime': chordStartTime,
            'duration': chordDuration,
            'baseTempo': baseTempo,
            'isSlurStart': false,
            'isSlurEnd': false,
            'measure': measureCount,
            'noteIndex': noteIndex, // Gán noteIndex cho chord cuối
          });
        }
      }
    }

    midiEvents = _processRepeats(tempMidiEvents, repeatStartMeasures, repeatEndMeasures);
    midiEvents.sort((a, b) => a['startTime'].compareTo(b['startTime']));
    return midiEvents;
  }

  static Map<String, int> _getKeySignatureAlterations(int fifths) {
    final sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
    final flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];
    Map<String, int> alterations = {};
    if (fifths > 0) {
      for (int i = 0; i < fifths && i < sharpOrder.length; i++) {
        alterations[sharpOrder[i]] = 1;
      }
    } else if (fifths < 0) {
      for (int i = 0; i < -fifths && i < flatOrder.length; i++) {
        alterations[flatOrder[i]] = -1;
      }
    }
    return alterations;
  }

  static int? _stepToMidiNote(
      String? step,
      int octave,
      Map<String, int> keySignature,
      String? accidental,
      Map<String, int> measureAccidentals,
      String noteKey,
      ) {
    if (step == null) return null;
    const noteMap = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final base = noteMap[step.toUpperCase()];
    if (base == null) return null;

    int alteration = keySignature[step.toUpperCase()] ?? 0;

    if (measureAccidentals.containsKey(noteKey)) {
      alteration = measureAccidentals[noteKey]!;
    }

    if (accidental != null) {
      alteration = {
        'sharp': 1,
        'flat': -1,
        'natural': 0,
        'double-sharp': 2,
        'double-flat': -2,
        'sharp-sharp': 2,
        'flat-flat': -2,
      }[accidental] ?? 0;
      measureAccidentals[noteKey] = alteration;
    }

    return base + alteration + (octave + 1) * 12;
  }

  static List<Map<String, dynamic>> _processRepeats(
      List<Map<String, dynamic>> events,
      List<int> startMeasures,
      List<int> endMeasures,
      ) {
    List<Map<String, dynamic>> finalEvents = [];
    int currentMeasure = 1;
    int repeatIndex = 0;
    bool inRepeat = false;
    double timeOffset = 0.0;

    for (var event in events) {
      final measure = event['measure'] as int;

      if (startMeasures.contains(measure) && !inRepeat) {
        inRepeat = true;
        repeatIndex++;
      }

      final newEvent = Map<String, dynamic>.from(event);
      newEvent['startTime'] = event['startTime'] + timeOffset;
      finalEvents.add(newEvent);

      if (endMeasures.contains(measure) && inRepeat) {
        inRepeat = false;
        final startMeasure = startMeasures[repeatIndex - 1];
        final repeatEvents = events
            .where((e) => e['measure'] >= startMeasure && e['measure'] <= measure)
            .toList();
        final repeatDuration = repeatEvents.last['startTime'] +
            repeatEvents.last['duration'] -
            repeatEvents.first['startTime'];
        timeOffset += repeatDuration;
        for (var repeatEvent in repeatEvents) {
          final newRepeatEvent = Map<String, dynamic>.from(repeatEvent);
          newRepeatEvent['startTime'] = repeatEvent['startTime'] + timeOffset;
          finalEvents.add(newRepeatEvent);
        }
      }
    }

    return finalEvents;
  }
}