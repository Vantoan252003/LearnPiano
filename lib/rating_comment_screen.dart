import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rating_comment_handler.dart';
import 'login_screen.dart';

class RatingCommentScreen extends StatefulWidget {
  final String filePath;

  const RatingCommentScreen({required this.filePath, Key? key}) : super(key: key);

  @override
  _RatingCommentScreenState createState() => _RatingCommentScreenState();
}

class _RatingCommentScreenState extends State<RatingCommentScreen> {
  final RatingCommentHandler _ratingCommentHandler = RatingCommentHandler();
  final TextEditingController _commentController = TextEditingController();
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    print('RatingCommentScreen: Khởi tạo với filePath: ${widget.filePath}');
    _loadAverageRating();
  }

  Future<void> _loadAverageRating() async {
    final avgRating = await _ratingCommentHandler.getAverageRating(widget.filePath);
    if (mounted) {
      setState(() {
        _averageRating = avgRating;
      });
    }
  }

  Future<void> _submitRating(double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    print('submitRating: user = ${user?.uid}, displayName = ${user?.displayName}');
    if (user == null) {
      print('submitRating: Yêu cầu đăng nhập');
      _showLoginPrompt();
      return;
    }
    try {
      await _ratingCommentHandler.saveRating(widget.filePath, rating.toInt());
      await _loadAverageRating();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đánh giá đã được lưu')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    print('submitComment: user = ${user?.uid}, displayName = ${user?.displayName}');
    if (user == null) {
      print('submitComment: Yêu cầu đăng nhập');
      _showLoginPrompt();
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập bình luận')),
      );
      return;
    }
    try {
      await _ratingCommentHandler.saveComment(widget.filePath, _commentController.text);
      _commentController.clear();
      setState(() {}); // Buộc làm mới giao diện
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bình luận đã được gửi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu đăng nhập'),
        content: const Text('Vui lòng đăng nhập để đánh giá hoặc bình luận.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đánh giá và Bình luận',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Đánh giá bản nhạc:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          RatingBar.builder(
            initialRating: 0,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: _submitRating,
          ),
          const SizedBox(height: 8),
          Text(
            'Đánh giá trung bình: ${_averageRating.toStringAsFixed(1)} sao',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Viết bình luận:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Nhập bình luận của bạn...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitComment,
            child: const Text('Gửi bình luận'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bình luận:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _ratingCommentHandler.getComments(widget.filePath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('StreamBuilder: Không có dữ liệu bình luận');
                  return const Text('Chưa có bình luận nào.');
                }
                final comments = snapshot.data!;
                print('StreamBuilder: Hiển thị ${comments.length} bình luận');
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      title: Text(comment['displayName']),
                      subtitle: Text(comment['comment']),
                      trailing: Text(
                        comment['timestamp'].toString().substring(0, 16),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}