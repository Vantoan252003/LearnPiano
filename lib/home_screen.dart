import 'package:flutter/material.dart';
import 'piano_challenge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Học Piano",
          style: TextStyle(color: Colors.white, fontSize: 30),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                "Menu",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.teal),
              title: const Text("Thành tựu"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.equalizer, color: Colors.teal),
              title: const Text("Phân tích"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.teal),
              title: const Text("Khóa nhạc"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.teal),
              title: const Text("Cài đặt"),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCircle("Bài tập", "0", Icons.check_circle),
                _buildStatCircle("Điểm ", "0", Icons.show_chart),
                _buildStatCircle("Giây ", "0", Icons.timer),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Text("A", style: TextStyle(color: Colors.black)),
                ),
                const SizedBox(width: 10),
                const Expanded(child:
                Text("Tiếp tục\nbài tập"),)
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(String title, String value, IconData icon) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[800],
          child: Icon(icon, size: 30, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMenuTile(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.teal),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
