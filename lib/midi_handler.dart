import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class MidiHandler {
  final BuildContext context;
  MidiPro? _midiPro;
  int? _sfId;
  bool _isPlaying = false;

  MidiHandler(this.context) {
    _initializeMidi();
  }

  Future<void> _initializeMidi() async {
    _midiPro = MidiPro();
    final tempDir = await getTemporaryDirectory();
    final soundFontFile = File('${tempDir.path}/Grand_Piano.sf2');
    final soundFontData = await DefaultAssetBundle.of(context).load('assets/Grand_Piano.sf2');
    await soundFontFile.writeAsBytes(soundFontData.buffer.asUint8List());
    _sfId = await _midiPro!.loadSoundfont(
      path: soundFontFile.path,
      bank: 0,
      program: 0,
    );
  }

  Future<void> playMusic(
      List<Map<String, dynamic>> midiEvents,
      double tempoMultiplier,
      VoidCallback onFinished,
      ) async {
    if (_midiPro == null || _sfId == null) return;

    _isPlaying = false;
    await Future.delayed(const Duration(milliseconds: 100));
    for (var event in midiEvents) {
      for (var midi in event['midiNotes'] as List<int>) {
        await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
      }
    }

    _isPlaying = true;

    final events = [
      ...midiEvents.map(
            (e) => {
          'midiNotes': e['midiNotes'],
          'time': e['startTime'] / tempoMultiplier,
          'duration': e['duration'] / tempoMultiplier,
          'action': 'start',
          'isSlurStart': e['isSlurStart'] ?? false,
          'isSlurEnd': e['isSlurEnd'] ?? false,
        },
      ),
      ...midiEvents.map(
            (e) => {
          'midiNotes': e['midiNotes'],
          'time': (e['startTime'] + e['duration']) / tempoMultiplier,
          'action': 'stop',
          'isSlurStart': e['isSlurStart'] ?? false,
          'isSlurEnd': e['isSlurEnd'] ?? false,
        },
      ),
    ]..sort((a, b) => a['time'].compareTo(b['time']));

    final startTime = DateTime.now();
    int eventIndex = 0;

    while (eventIndex < events.length && _isPlaying) {
      final elapsedSeconds = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      while (eventIndex < events.length &&
          events[eventIndex]['time'] <= elapsedSeconds &&
          _isPlaying) {
        final event = events[eventIndex];
        final midiNotes = event['midiNotes'] as List<int>;
        final action = event['action'] as String;
        final isSlurStart = event['isSlurStart'] as bool;
        final isSlurEnd = event['isSlurEnd'] as bool;
        int velocity = 127;

        if (isSlurStart || isSlurEnd) {
          velocity = 100;
        }

        for (var midi in midiNotes) {
          if (action == 'start') {
            await _midiPro!.playNote(
              channel: 0,
              key: midi,
              velocity: velocity,
              sfId: _sfId!,
            );
          } else {
            await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
          }
        }
        eventIndex++;
      }

      if (!_isPlaying) break;
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isPlaying = false;
    onFinished();
  }

  Future<void> stopMusic() async {
    if (_midiPro == null || _sfId == null) return;
    _isPlaying = false;
  }

  void dispose() {
    if (_midiPro != null && _sfId != null) {
      _isPlaying = false;
    }
  }
}