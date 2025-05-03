import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Class để lưu trữ vị trí phát hiện tại
class PlaybackPosition {
  final int measure;
  final int note;

  PlaybackPosition(this.measure, this.note);
}

class MidiHandler {
  final BuildContext context;
  MidiPro? _midiPro;
  int? _sfId;
  bool _isPlaying = false;

  // StreamController để thông báo vị trí hiện tại
  final _positionController = StreamController<PlaybackPosition>.broadcast();

  // Stream công khai để các widget khác có thể lắng nghe
  Stream<PlaybackPosition> get positionStream => _positionController.stream;

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

    // Dừng toàn bộ âm thanh đang phát
    _isPlaying = false;
    await Future.delayed(const Duration(milliseconds: 100));
    for (var event in midiEvents) {
      for (var midi in event['midiNotes'] as List<int>) {
        await _midiPro!.stopNote(channel: 0, key: midi, sfId: _sfId!);
      }
    }

    _isPlaying = true;

    // Chuẩn bị danh sách sự kiện, thêm thông tin measure và noteIndex
    final events = [
      ...midiEvents.map(
            (e) => {
          'midiNotes': e['midiNotes'],
          'time': e['startTime'] / tempoMultiplier,
          'duration': e['duration'] / tempoMultiplier,
          'action': 'start',
          'isSlurStart': e['isSlurStart'] ?? false,
          'isSlurEnd': e['isSlurEnd'] ?? false,
          'measure': e['measure'] ?? 0,    // Thêm thông tin về measure
          'noteIndex': e['noteIndex'] ?? 0, // Thêm thông tin về vị trí trong measure
        },
      ),
      ...midiEvents.map(
            (e) => {
          'midiNotes': e['midiNotes'],
          'time': (e['startTime'] + e['duration']) / tempoMultiplier,
          'action': 'stop',
          'isSlurStart': e['isSlurStart'] ?? false,
          'isSlurEnd': e['isSlurEnd'] ?? false,
          'measure': e['measure'] ?? 0,
          'noteIndex': e['noteIndex'] ?? 0,
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

        // Nếu là sự kiện bắt đầu nốt nhạc, thông báo vị trí hiện tại
        if (action == 'start') {
          // Phát ra sự kiện vị trí hiện tại
          final measure = event['measure'] as int;
          final noteIndex = event['noteIndex'] as int;
          _positionController.add(PlaybackPosition(measure, noteIndex));

          // Phát âm thanh
          for (var midi in midiNotes) {
            await _midiPro!.playNote(
              channel: 0,
              key: midi,
              velocity: velocity,
              sfId: _sfId!,
            );
          }
        } else {
          // Dừng nốt nhạc
          for (var midi in midiNotes) {
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

  // Phát một nốt duy nhất (hữu ích khi người dùng click vào sheet nhạc)
  Future<void> playNote(int midiNote, {int velocity = 127}) async {
    if (_midiPro == null || _sfId == null) return;

    await _midiPro!.playNote(
      channel: 0,
      key: midiNote,
      velocity: velocity,
      sfId: _sfId!,
    );

    // Tự động dừng nốt sau 500ms
    await Future.delayed(const Duration(milliseconds: 500));
    await _midiPro!.stopNote(channel: 0, key: midiNote, sfId: _sfId!);
  }

  // Nhảy đến vị trí cụ thể trong sheet nhạc (khi người dùng click vào)
  void seekToPosition(int measure, int note) {
    // Thông báo vị trí mới
    _positionController.add(PlaybackPosition(measure, note));
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    if (_midiPro != null && _sfId != null) {
      _isPlaying = false;
    }
    // Đóng StreamController khi không dùng nữa
    _positionController.close();
  }
}