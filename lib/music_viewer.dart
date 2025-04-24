import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_xml/music_xml.dart';
import 'package:xml/xml.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For FirebaseStorage
import 'dart:io'; // For Directory and File
import 'package:http/http.dart' as http; // For http
import 'dart:convert'; // For utf8
import 'package:archive/archive.dart'; // For ZipDecoder
import 'package:path_provider/path_provider.dart'; // For getTemporaryDirectory

class MusicViewer extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isLocalFile;

  const MusicViewer({
    required this.filePath,
    required this.fileName,
    this.isLocalFile = false,
    Key? key,
  }) : super(key: key);

  @override
  State<MusicViewer> createState() => _MusicViewerState();
}

class _MusicViewerState extends State<MusicViewer> {
  bool _isLoading = true;
  String? _fileContent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMusicFile();
  }

  Future<void> _loadMusicFile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      late File fileToRead;

      if (widget.isLocalFile) {
        // If file is local, use it directly
        fileToRead = File(widget.filePath);
      } else {
        // Get download URL from Firebase Storage
        final ref = FirebaseStorage.instance.ref(widget.filePath);
        final url = await ref.getDownloadURL();

        // Download the file to a temporary directory
        final Directory tempDir = await getTemporaryDirectory();
        fileToRead = File('${tempDir.path}/${widget.fileName}');

        // Download file from URL
        final response = await http.get(Uri.parse(url));
        await fileToRead.writeAsBytes(response.bodyBytes);
      }

      // Check if it's an MXL file (zip archive)
      if (widget.fileName.toLowerCase().endsWith('.mxl')) {
        // Parse the MXL file (which is a ZIP file containing XML)
        final bytes = await fileToRead.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Find the main musicXML file in the archive
        final xmlFile = archive.firstWhere(
              (file) => file.name.endsWith('.xml'),
          orElse: () => throw Exception('No XML file found in the MXL archive'),
        );

        // Convert the file content to string
        final xmlContent = utf8.decode(xmlFile.content as List<int>);
        setState(() {
          _fileContent = xmlContent;
          _isLoading = false;
        });
      } else if (widget.fileName.toLowerCase().endsWith('.xml')) {
        // Direct XML file
        final xmlContent = await fileToRead.readAsString();
        setState(() {
          _fileContent = xmlContent;
          _isLoading = false;
        });
      } else {
        throw Exception('Unsupported file format. Only .mxl and .xml files are supported.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text('Error: $_errorMessage'))
          : _fileContent != null
          ? MusicContent(xmlContent: _fileContent!)
          : const Center(child: Text('No content available')),
    );
  }
}

class MusicContent extends StatelessWidget {
  final String xmlContent;

  const MusicContent({
    required this.xmlContent,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MusicXmlDocument>(
      future: Future.value(MusicXmlDocument.parse(xmlContent)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error parsing XML: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final document = snapshot.data!;
          final score = document.score;
          final scorePartwise = score.getElement('score-partwise');
          final movementTitle = scorePartwise?.getElement('movement-title');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: ${movementTitle?.innerText ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Total Time: ${document.totalTimeSecs} seconds'),
                const SizedBox(height: 16),
                const Text('Score Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                // Add more music score details here
              ],
            ),
          );
        }
        return const Center(child: Text('No data available'));
      },
    );
  }
}