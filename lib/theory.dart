import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TheoryPage extends StatelessWidget {
  // Hàm để thêm dữ liệu mẫu vào Firestore
  Future<void> addSampleData() async {
    // Thêm dữ liệu vào collection "notes"

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Piano Theory'),
      ),
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
                child: Text('Add Sample Data to Firestore'),
              ),
            ),
            // Hiển thị danh sách nốt nhạc
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Notes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder(
              stream: FirebaseFirestore.instance.collection('notes').snapshots(),
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
                      title: Text(doc['name']),
                      subtitle: Text(doc['description']),
                      trailing: Text('Frequency: ${doc['frequency']} Hz'),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder(
              stream: FirebaseFirestore.instance.collection('chords').snapshots(),
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
                      title: Text(doc['name']),
                      subtitle: Text(doc['description']),
                      trailing: Text('Notes: ${doc['notes'].join(', ')}'),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder(
              stream: FirebaseFirestore.instance.collection('lessons').snapshots(),
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
                      title: Text(doc['title']),
                      subtitle: Text(doc['content']),
                      trailing: Text('Level: ${doc['level']}'),
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