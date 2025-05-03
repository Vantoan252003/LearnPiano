import 'package:flutter/material.dart';
import 'package:music_xml/music_xml.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'music_controls.dart';

class MusicContent extends StatefulWidget {
  final String xmlContent;
  final VoidCallback onPlay;
  final VoidCallback onRewind;
  final bool isPlaying;
  final double tempoMultiplier;
  final ValueChanged<double> onTempoChanged;
  final void Function(int measure, int note)? onNoteChanged;
  final Stream<PlaybackPosition>? playbackPositionStream;

  const MusicContent({
    required this.xmlContent,
    required this.onPlay,
    required this.onRewind,
    required this.isPlaying,
    required this.tempoMultiplier,
    required this.onTempoChanged,
    this.onNoteChanged,
    this.playbackPositionStream,
    Key? key,
  }) : super(key: key);

  @override
  State<MusicContent> createState() => _MusicContentState();
}

class PlaybackPosition {
  final int measure;
  final int note;

  PlaybackPosition(this.measure, this.note);
}

class _MusicContentState extends State<MusicContent> {
  late WebViewController controller;
  String? documentTitle;
  bool isWebViewReady = false;
  double _scale = 1.0;
  Timer? _debounceTimer;
  PlaybackPosition? _lastPosition;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              isWebViewReady = true;
            });
            _loadMusicXML();
          },
        ),
      )
      ..addJavaScriptChannel(
        'PlaybackPositionChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          if (isWebViewReady && data['measure'] != null && data['note'] != null) {
            _highlightNote(data['measure'], data['note']);
          }
        },
      )
      ..addJavaScriptChannel(
        'NoteEventChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          if (widget.onNoteChanged != null) {
            widget.onNoteChanged!(data['measure'], data['note']);
          }
        },
      )
      ..loadHtmlString(_buildHtmlWithOSMD());

    _extractTitleFromXML();

    widget.playbackPositionStream?.listen((position) {
      if (_lastPosition?.measure != position.measure || _lastPosition?.note != position.note) {
        _lastPosition = position;
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 100), () {
          if (isWebViewReady) {
            final jsonPosition = jsonEncode({'measure': position.measure, 'note': position.note});
            controller.runJavaScript('updatePlaybackPosition($jsonPosition)');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MusicContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (!widget.isPlaying) {
        _clearHighlights();
      }
    }

    if (widget.xmlContent != oldWidget.xmlContent) {
      _extractTitleFromXML();
      _loadMusicXML();
    }
  }

  void _extractTitleFromXML() {
    try {
      final document = MusicXmlDocument.parse(widget.xmlContent);
      final scorePartwise = document.score.getElement('score-partwise');
      documentTitle = scorePartwise?.getElement('movement-title')?.text ?? 'Unknown';
      setState(() {});
    } catch (e) {
      debugPrint('Error extracting title: $e');
      documentTitle = 'Unknown';
    }
  }

  Future<void> _loadMusicXML() async {
    if (isWebViewReady) {
      final escaped = jsonEncode(widget.xmlContent);
      await controller.runJavaScript('loadMusicXML($escaped)');
    }
  }

  Future<void> _updateZoom() async {
    if (isWebViewReady) {
      await controller.runJavaScript('setZoom($_scale)');
    }
  }

  Future<void> _highlightNote(int measureIndex, int noteIndex) async {
    if (isWebViewReady) {
      await controller.runJavaScript('highlightNote($measureIndex, $noteIndex)');
    }
  }

  Future<void> _clearHighlights() async {
    if (isWebViewReady) {
      await controller.runJavaScript('clearHighlights()');
    }
  }

  String _buildHtmlWithOSMD() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Piano Sheet Music</title>
      <style>
        body {
          margin: 0;
          padding: 0;
          background: white;
          font-family: Arial, sans-serif;
          overflow-x: hidden;
        }
        #container {
          width: 100%;
          transform-origin: top left;
        }
        .osmd-cursor {
          fill: rgba(0, 128, 0, 0.25) !important;
          stroke: #008000 !important;
          stroke-width: 2px;
        }
        .highlighted-note {
          fill: #FF0000 !important;
          stroke: #FF0000 !important;
        }
      </style>
      <script src="https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.7.4/build/opensheetmusicdisplay.min.js"></script>
    </head>
    <body>
      <div id="container"></div>

      <script>
        let osmd;
        let cursor;
        let lastMeasure = -1;
        let lastNote = -1;

        function setZoom(scale) {
          const container = document.getElementById("container");
          container.style.transform = `scale(\${scale})`;
          container.style.width = (100/scale) + "%";
        }

        function loadMusicXML(xmlString) {
          const container = document.getElementById("container");
          container.innerHTML = '';

          try {
            osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay(container);
            osmd.setOptions({
              backend: "svg",
              drawTitle: true,
              drawSubtitle: true,
              drawPartNames: true,
              drawMeasureNumbers: true,
              autoResize: true
            });

            osmd.load(xmlString)
              .then(() => {
                console.log("Music XML loaded successfully");
                osmd.EngravingRules.StaffHeight = 4;
                osmd.EngravingRules.StaffDistance = 0.005;
                osmd.EngravingRules.PageTopMargin = 3;
                osmd.EngravingRules.PageBottomMargin = 3;
                osmd.EngravingRules.PageLeftMargin = 2;
                osmd.EngravingRules.PageRightMargin = 2;

                osmd.render();
                console.log("Sheet music rendered successfully");

                setupCursor();
                setupNoteClickHandlers();
              })
              .catch(err => {
                container.innerHTML = '<p>Error loading music XML: ' + err.message + '</p>';
                console.error("Error loading music XML:", err);
              });
          } catch (e) {
            container.innerHTML = '<p>Error initializing OSMD: ' + e.message + '</p>';
            console.error("Error initializing OSMD:", e);
          }
        }

        function setupCursor() {
          try {
            if (!osmd) return;
            cursor = osmd.cursor;
            if (cursor) {
              cursor.show();
              console.log("Cursor initialized successfully");
              if (lastMeasure >= 0 && lastNote >= 0) {
                highlightNote(lastMeasure, lastNote);
              }
            }
          } catch (err) {
            console.error("Error setting up cursor:", err);
          }
        }

        function setupNoteClickHandlers() {
          try {
            setTimeout(() => {
              const notes = document.querySelectorAll(".vf-stavenote");
              console.log("Found", notes.length, "note elements");

              if (notes.length > 0) {
                notes.forEach((noteElement, idx) => {
                  noteElement.addEventListener("click", () => {
                    let measureIdx = -1;
                    let noteIdx = -1;
                    for (let m = 0; m < osmd.graphic.measureList.length; m++) {
                      const measure = osmd.graphic.measureList[m];
                      for (let s = 0; s < measure.length; s++) {
                        const staff = measure[s];
                        for (let n = 0; n < staff.staffEntries.length; n++) {
                          const entry = staff.staffEntries[n];
                          for (let v = 0; v < entry.graphicalVoiceEntries.length; v++) {
                            const voiceEntry = entry.graphicalVoiceEntries[v];
                            for (let note of voiceEntry.notes) {
                              if (note.sourceNote && noteElement.getAttribute('data-id') === `\${note.sourceNote.NoteId}`) {
                                measureIdx = m;
                                noteIdx = n;
                                break;
                              }
                            }
                            if (measureIdx >= 0) break;
                          }
                          if (measureIdx >= 0) break;
                        }
                        if (measureIdx >= 0) break;
                      }
                      if (measureIdx >= 0) break;
                    }

                    if (measureIdx >= 0 && noteIdx >= 0) {
                      console.log("Clicked measure", measureIdx, "note", noteIdx);
                      NoteEventChannel.postMessage(JSON.stringify({
                        measure: measureIdx,
                        note: noteIdx
                      }));
                    }
                  });
                });
              }
            }, 300);
          } catch (err) {
            console.error("Error setting up click handlers:", err);
          }
        }

        function updatePlaybackPosition(position) {
          if (position.measure !== undefined && position.note !== undefined) {
            highlightNote(position.measure, position.note);
          } else {
            console.warn("Invalid playback position:", position);
          }
        }

        function highlightNote(measureIndex, noteIndex) {
          if (!osmd || !cursor) {
            console.error("OSMD or cursor not initialized");
            return;
          }

          // Adjust measureIndex (OSMD uses 0-based, MusicXML uses 1-based)
          measureIndex = measureIndex - 1;
          if (measureIndex < 0 || measureIndex >= osmd.graphic.measureList.length) {
            console.error("Invalid measure index:", measureIndex, "Total measures:", osmd.graphic.measureList.length);
            return;
          }

          // Validate noteIndex
          const measure = osmd.graphic.measureList[measureIndex];
          if (!measure || measure.length === 0 || !measure[0].staffEntries) {
            console.error("Invalid measure structure at index:", measureIndex);
            return;
          }
          const staffEntries = measure[0].staffEntries;
          if (noteIndex < 0 || noteIndex >= staffEntries.length) {
            console.error("Invalid note index:", noteIndex, "Total notes in measure:", staffEntries.length);
            return;
          }

          clearHighlights();

          cursor.reset();
          try {
            for (let i = 0; i <= measureIndex; i++) {
              const maxNotes = (i === measureIndex) ? noteIndex + 1 : osmd.graphic.measureList[i][0].staffEntries.length;
              for (let j = 0; j < maxNotes; j++) {
                if (i === measureIndex && j === noteIndex) break;
                cursor.next();
              }
            }

            const notesUnderCursor = osmd.cursor.NotesUnderCursor();
            if (notesUnderCursor && notesUnderCursor.length > 0) {
              const noteElement = document.querySelector(`.vf-stavenote[data-id="\${notesUnderCursor[0].sourceNote.NoteId}"]`);
              if (noteElement) {
                noteElement.classList.add("highlighted-note");
              } else {
                console.warn("Note element not found for cursor position");
              }
            } else {
              console.warn("No notes under cursor at measure", measureIndex, "note", noteIndex);
            }

            lastMeasure = measureIndex;
            lastNote = noteIndex;
            scrollCursorIntoView();
          } catch (err) {
            console.error("Error moving cursor:", err);
          }
        }

        function scrollCursorIntoView() {
          setTimeout(() => {
            const cursorEl = document.querySelector(".osmd-cursor");
            if (cursorEl) {
              cursorEl.scrollIntoView({
                behavior: "smooth",
                block: "center"
              });
            } else {
              console.warn("Cursor element not found");
            }
          }, 100);
        }

        function clearHighlights() {
          if (cursor) {
            cursor.hide();
          }

          document.querySelectorAll(".highlighted-note").forEach(el => {
            el.classList.remove("highlighted-note");
          });
        }
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.zoom_out),
                onPressed: () {
                  setState(() {
                    _scale = (_scale - 0.1).clamp(0.5, 2.0);
                    _updateZoom();
                  });
                },
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text('${(_scale * 100).round()}%', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                onPressed: () {
                  setState(() {
                    _scale = (_scale + 0.1).clamp(0.5, 2.0);
                    _updateZoom();
                  });
                },
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        Expanded(
          flex: 9,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: isWebViewReady
                ? WebViewWidget(controller: controller)
                : const Center(child: CircularProgressIndicator()),
          ),
        ),

        MusicControls(
          onPlay: widget.onPlay,
          onRewind: widget.onRewind,
          isPlaying: widget.isPlaying,
          tempoMultiplier: widget.tempoMultiplier,
          onTempoChanged: widget.onTempoChanged,
        ),
      ],
    );
  }
}