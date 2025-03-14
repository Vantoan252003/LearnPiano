import 'package:flutter/material.dart';
import 'home_screen.dart';
void main(){
  runApp(LearnPiano());
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