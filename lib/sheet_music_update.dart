// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:file_picker/file_picker.dart';
//
// class SheetUpload extends StatefulWidget {
//   const SheetUpload({super.key});
//
//   @override
//   _UploadSheet createState() => _UploadSheet();
// }
//
// class _UploadSheet extends State<SheetUpload> {
//   File? _file;
//   String? _fileName;
//   bool _isUploading = false;
//
//   Future<void> pickFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       allowMultiple: true,
//       type: FileType.custom,
//       allowedExtensions: ['pdf'],
//     );
//     if (result != null &&
//         result.files.isNotEmpty &&
//         result.files.single.path != null) {
//       setState(() {
//         _file = File(result.files.single.path!);
//         _fileName = result.files.single.name;
//       });
//     }
//   }
// }
