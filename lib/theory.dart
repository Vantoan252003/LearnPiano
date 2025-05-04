import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TheoryPage extends StatelessWidget {
  const TheoryPage({super.key});

  // Hàm để thêm dữ liệu mẫu vào Firestore
  Future<void> addSampleData() async {
    // Thêm dữ liệu vào collection "notes"
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(style: TextStyle(color: Colors.white), 'Piano Theory')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nút để thêm dữ liệu mẫu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () async {
                  await addSampleData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sample data added to Firestore')),
                  );
                },
                child: Text('thêm dữ liệu vào firestore'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Lý thuyết phím đàn',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            StreamBuilder(
              stream:
                  FirebaseFirestore.instance
                      .collection('piano_keyboard')
                      .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return ListTile(subtitle: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['theory']));
                  },
                );
              },
            ),
            // Hiển thị danh sách nốt nhạc
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Notes',
                style: TextStyle(color: Colors.white,fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('notes').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['name']),
                      subtitle: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['description']),
                      trailing: Text(style: TextStyle(color: Colors.white,fontSize: 15),'Frequency: ${doc['frequency']} Hz'),
                    );
                  },
                );
              },
            ),
            // Hiển thị danh sách hợp âm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Chords',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('chords').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['name']),
                      subtitle: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['description']),
                      trailing: Text(style: TextStyle(color: Colors.white,fontSize: 15),'Notes: ${doc['notes'].join(', ')}'),
                    );
                  },
                );
              },
            ),
            // Hiển thị danh sách bài học
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Lessons',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('lessons').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['title']),
                      subtitle: Text(style: TextStyle(color: Colors.white,fontSize: 15),doc['content']),
                      trailing: Text(style: TextStyle(color: Colors.white,fontSize: 15),'Level: ${doc['level']}'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
