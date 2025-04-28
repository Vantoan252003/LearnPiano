import 'package:flutter/material.dart';

class MusicControls extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onRewind;
  final bool isPlaying;
  final double tempoMultiplier;
  final ValueChanged<double> onTempoChanged;

  const MusicControls({
    required this.onPlay,
    required this.onRewind,
    required this.isPlaying,
    required this.tempoMultiplier,
    required this.onTempoChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          const Text(
            'Adjust Tempo:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Slider(
            value: tempoMultiplier,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${(tempoMultiplier * 100).toInt()}%',
            onChanged: onTempoChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay),
                onPressed: onRewind,
                tooltip: 'Rewind',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: onPlay,
                tooltip: isPlaying ? 'Pause' : 'Play',
              ),
            ],
          ),
        ],
      ),
    );
  }
}