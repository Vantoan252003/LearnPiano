import 'package:flutter/material.dart';
import 'package:learn_piano/play_sheet.dart';
import 'package:learn_piano/theory.dart';
import 'piano_challenge.dart';
import 'theory.dart';
import 'sheet_music.dart';
import 'package:learn_piano/piano_keyboard.dart';
import 'chord_ear_training.dart';
import 'eartrainning.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Thêm Firestore
import 'edit_profile_screen.dart'; // Thêm màn hình chỉnh sửa hồ sơ

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Kiểm tra trạng thái đăng nhập và lấy thông tin người dùng
    bool isLoggedIn = AuthService().getCurrentUser() != null;
    String? userId = AuthService().getCurrentUser()?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[900], // Nền tối hơn
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        title: const Text(
          "Học Piano",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.grey[850],
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.grey[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: isLoggedIn && userId != null
                    ? FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Text(
                        'Lỗi khi tải thông tin',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Text(
                        'Không tìm thấy thông tin người dùng',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      );
                    }

                    var userData = snapshot.data!.data() as Map<String, dynamic>;
                    String name = userData['name'] ?? 'Người dùng';
                    String avatar = userData['avatar'] ?? 'https://example.com/default-avatar.png';

                    // Biến để theo dõi lỗi tải ảnh
                    bool hasImageError = false;

                    return Row(
                      children: [
                        StatefulBuilder(
                          builder: (context, setState) {
                            return CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(avatar),
                              backgroundColor: Colors.grey[700],
                              onBackgroundImageError: (error, stackTrace) {
                                // Cập nhật trạng thái khi có lỗi tải ảnh
                                setState(() {
                                  hasImageError = true;
                                });
                              },
                              child: hasImageError || avatar.isEmpty
                                  ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              )
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AuthService().getCurrentUser()?.email ?? 'Chưa đăng nhập',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                )
                    : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Menu",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chưa đăng nhập',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(Icons.emoji_events, "Thành tựu", () {}),
              _buildDrawerItem(Icons.equalizer, "Phân tích", () {}),
              _buildDrawerItem(Icons.music_note, "Khóa nhạc", () {}),
              _buildDrawerItem(Icons.settings, "Cài đặt", () {}),
              if (isLoggedIn)
                _buildDrawerItem(Icons.person, "Chỉnh sửa hồ sơ", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  );
                }),
              if (isLoggedIn)
                _buildDrawerItem(Icons.lock, "Thay đổi mật khẩu", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
                }),
              _buildDrawerItem(
                isLoggedIn ? Icons.logout : Icons.login,
                isLoggedIn ? "Đăng xuất" : "Đăng nhập",
                    () async {
                  if (isLoggedIn) {
                    await AuthService().logout();
                    setState(() {}); // Cập nhật giao diện sau khi đăng xuất
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh tiến độ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCircle(
                      "Bài tập",
                      "0",
                      Icons.check_circle,
                      Colors.blueAccent,
                    ),
                    _buildStatCircle(
                      "Điểm",
                      "0",
                      Icons.show_chart,
                      Colors.greenAccent,
                    ),
                    _buildStatCircle(
                      "Giây",
                      "0",
                      Icons.timer,
                      Colors.orangeAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Featured Section
              const Text(
                "Khám phá ngay",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildFeaturedCard(
                context,
                "Nhận diện phím đàn",
                Icons.music_note,
                Colors.blue[700]!,
                const PianoChallenge(),
              ),
              _buildFeaturedCard(
                context,
                "Bàn phím Piano",
                Icons.piano,
                Colors.red[700]!,
                const PianoKeyboard(),
              ),
              _buildFeaturedCard(
                context,
                "Đoán hợp âm",
                Icons.queue_music_sharp,
                Colors.deepOrange,
                ChordTraining(),
              ),
              _buildFeaturedCard(
                context,
                "Luyện cảm âm",
                Icons.hearing_rounded,
                Colors.greenAccent[700]!,
                const EarTrainning(),
              ),
              const SizedBox(height: 20),
              // Menu Grid
              const Text(
                "Công cụ học tập",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildMenuTile(
                    "Nhận diện phím đàn",
                    Icons.hearing,
                    Colors.purple[600]!,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PianoChallenge(),
                        ),
                      );
                    },
                  ),
                  _buildMenuTile(
                    "Luyện nhịp",
                    Icons.music_note,
                    Colors.teal[600]!,
                        () {},
                  ),
                  _buildMenuTile(
                    "Lý thuyết",
                    Icons.book,
                    Colors.indigo[600]!,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TheoryPage()),
                      );
                    },
                  ),
                  _buildMenuTile(
                    "Sheet nhạc",
                    Icons.my_library_books,
                    Colors.orange[600]!,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SheetMusic()),
                      );
                    },
                  ),
                  _buildMenuTile(
                    "Xem sheet nhạc",
                    Icons.music_note,
                    Colors.green[600]!,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PlaySheet()),
                      );
                    },
                  ),
                  _buildMenuTile(
                    "Thành tựu",
                    Icons.emoji_events,
                    Colors.yellow[700]!,
                        () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      onTap: onTap,
      tileColor: Colors.transparent,
      hoverColor: Colors.grey[700],
    );
  }

  Widget _buildStatCircle(
      String title,
      String value,
      IconData icon,
      Color accentColor,
      ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: accentColor,
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      ],
    );
  }

  Widget _buildFeaturedCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      Widget destination,
      ) {
    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => destination),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Bắt đầu",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
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