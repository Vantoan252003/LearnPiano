import 'package:flutter/material.dart';
import 'package:learn_piano/play_sheet.dart';
import 'package:learn_piano/profile_screen.dart';
import 'package:learn_piano/theory.dart';
import 'piano_challenge.dart';
import 'sheet_music.dart';
import 'package:learn_piano/piano_keyboard.dart';
import 'chord_ear_training.dart';
import 'eartrainning.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'note_recognition.dart';
import 'bass_note_recognition.dart';
import 'chord_without_sheet.dart';
import 'melody_recognition.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService().getCurrentUser() != null;
    final user = AuthService().getCurrentUser();
    final userEmail = user?.email;
    final userName = user?.displayName ?? userEmail ?? "";
    final userPhoto = user?.photoURL;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.piano, color: Colors.white, size: 32),
            const SizedBox(width: 10),
            const Text(
              "Piano Master",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed:
                isLoggedIn
                    ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    }
                    : null,
            tooltip: isLoggedIn ? "Hồ sơ" : null,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed:
                isLoggedIn
                    ? () async {
                      await AuthService().logout();
                      setState(() {});
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
                    : null,
            tooltip: isLoggedIn ? "Đăng xuất" : null,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              accountName: Text(
                isLoggedIn ? userName : "Khách",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                isLoggedIn ? userEmail ?? "" : "Chưa đăng nhập",
              ),
              currentAccountPicture: CircleAvatar(
                backgroundImage:
                    userPhoto != null ? NetworkImage(userPhoto) : null,
                backgroundColor: Colors.white10,
                child:
                    userPhoto == null
                        ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 36,
                        )
                        : null,
              ),
            ),
            if (isLoggedIn)
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: const Text(
                  "Hồ sơ",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.white),
              title: const Text(
                "Thay đổi mật khẩu",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isLoggedIn ? Icons.logout : Icons.login,
                color: Colors.white,
              ),
              title: Text(
                isLoggedIn ? "Đăng xuất" : "Đăng nhập",
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                if (isLoggedIn) {
                  await AuthService().logout();
                  setState(() {});
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Text(
                isLoggedIn
                    ? 'Chào mừng, $userName!'
                    : 'Chào mừng đến với Piano Master!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Cùng luyện tập và khám phá âm nhạc!",
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const SizedBox(height: 24),
              // Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _quickAction(
                    icon: Icons.music_note,
                    label: "Nhận diện phím",
                    color: Colors.blueAccent,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PianoChallenge(),
                          ),
                        ),
                  ),
                  _quickAction(
                    icon: Icons.piano,
                    label: "Piano ảo",
                    color: Colors.redAccent,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PianoKeyboard(),
                          ),
                        ),
                  ),
                  _quickAction(
                    icon: Icons.queue_music,
                    label: "Giai điệu",
                    color: Colors.deepOrange,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MelodyRecognitionGame(),
                          ),
                        ),
                  ),
                  _quickAction(
                    icon: Icons.hearing,
                    label: "Cảm âm",
                    color: Colors.green,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EarTrainning(),
                          ),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Study Tools
              const Text(
                "Công cụ học tập",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
                children: [
                  _toolCard(
                    title: "Nghe và đoán hợp âm",
                    icon: Icons.hearing,
                    color: Colors.purple,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChordWithoutSheet(),
                          ),
                        ),
                  ),
                  _toolCard(
                    title: "Nhận diện hợp âm",
                    icon: Icons.music_video,
                    color: Colors.purple,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChordTraining(),
                          ),
                        ),
                  ),
                  _toolCard(
                    title: "Nhận diện nốt (Khóa Sol)",
                    icon: Icons.music_note,
                    color: Colors.teal,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NoteRecognition(),
                          ),
                        ),
                  ),
                  _toolCard(
                    title: "Nhận diện nốt (Khóa Fa)",
                    icon: Icons.music_note_outlined,
                    color: Colors.deepPurple,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BassNoteRecognition(),
                          ),
                        ),
                  ),
                  _toolCard(
                    title: "Lý thuyết âm nhạc",
                    icon: Icons.book,
                    color: Colors.indigo,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TheoryPage()),
                        ),
                  ),

                  _toolCard(
                    title: "Xem sheet nhạc",
                    icon: Icons.music_video,
                    color: Colors.green,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PlaySheet()),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.18),
                radius: 28,
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
