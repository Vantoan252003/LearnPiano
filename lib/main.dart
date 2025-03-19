import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'home_screen.dart';
import 'sheet_music.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Lỗi khi khởi tạo Firebase: $e");
  }
  runApp(const LearnPiano());
}
class LearnPiano extends StatelessWidget{
  const LearnPiano({super.key});
  @override
  Widget build (BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}