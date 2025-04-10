import 'package:flutter/material.dart';
import 'package:flutter_piano_pro/flutter_piano_pro.dart';
import 'dart:math';

class ChordTraining extends StatefulWidget{
  const ChordTraining ({super.key});
  @override
  State<ChordTraining> createState() => _ChordTrainingState();
}
class _ChordTrainingState extends State<ChordTraining>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Đoán hợp âm', style: TextStyle(color: Colors.white),),
      ),
    );
  }
}