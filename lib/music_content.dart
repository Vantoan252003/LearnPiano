import 'package:flutter/material.dart';
import 'package:music_xml/music_xml.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'music_controls.dart';

class MusicContent extends StatelessWidget {
  final String xmlContent;
  final VoidCallback onPlay;
  final VoidCallback onRewind;
  final bool isPlaying;
  final double tempoMultiplier;
  final ValueChanged<double> onTempoChanged;

  const MusicContent({
    required this.xmlContent,
    required this.onPlay,
    required this.onRewind,
    required this.isPlaying,
    required this.tempoMultiplier,
    required this.onTempoChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MusicXmlDocument>(
      future: Future.value(MusicXmlDocument.parse(xmlContent)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final document = snapshot.data!;
          final scorePartwise = document.score.getElement('score-partwise');
          final movementTitle = scorePartwise?.getElement('movement-title')?.text ?? 'Unknown';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Title: $movementTitle',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SimpleSheetMusic(
                          measures: [], // Giữ rỗng để tránh lỗi
                          height: 400.0,
                          width: double.infinity,
                          lineColor: Colors.black54,
                          fontType: FontType.bravura,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Total Time: ${document.totalTimeSecs} seconds'),
                    ],
                  ),
                ),
              ),
              MusicControls(
                onPlay: onPlay,
                onRewind: onRewind,
                isPlaying: isPlaying,
                tempoMultiplier: tempoMultiplier,
                onTempoChanged: onTempoChanged,
              ),
            ],
          );
        }
        return const Center(child: Text('Không có dữ liệu'));
      },
    );
  }
}