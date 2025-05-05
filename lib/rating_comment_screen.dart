import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rating_comment_handler.dart';
import 'login_screen.dart';

class RatingCommentScreen extends StatefulWidget {
  final String filePath;

  const RatingCommentScreen({required this.filePath, super.key});

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
      final userRating = await _ratingCommentHandler.getUserRating(widget.filePath);
      await _ratingCommentHandler.saveComment(widget.filePath, _commentController.text, userRating);
      _commentController.clear();
      setState(() {}); // Làm mới giao diện
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bình luận đã được gửi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _deleteComment(String commentDocId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _ratingCommentHandler.deleteComment(widget.filePath, commentDocId);
                setState(() {}); // Làm mới giao diện
                Navigator.pop(context); // Đóng dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bình luận đã được xóa')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi: $e')),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(20.0), // Tăng padding tổng thể
      height: MediaQuery.of(context).size.height * 0.75, // Tăng chiều cao container
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0), // Bo góc container
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đánh giá và Bình luận',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đánh giá bản nhạc:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[600],
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          Text(
            'Đánh giá trung bình: ${_averageRating.toStringAsFixed(1)} sao',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey[500],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Viết bình luận:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[600],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Nhập bình luận của bạn...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                contentPadding: const EdgeInsets.all(12.0),
              ),
              maxLines: 4,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitComment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              elevation: 3,
            ),
            child: const Text(
              'Gửi bình luận',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bình luận:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[600],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _ratingCommentHandler.getComments(widget.filePath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('StreamBuilder: Không có dữ liệu bình luận');
                  return Text(
                    'Chưa có bình luận nào.',
                    style: TextStyle(color: Colors.grey[500]),
                  );
                }
                final comments = snapshot.data!;
                print('StreamBuilder: Hiển thị ${comments.length} bình luận');
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isOwnComment = comment['userId'] == FirebaseAuth.instance.currentUser?.uid;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ListTile(
                          title: Text(
                            comment['displayName'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                comment['comment'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueGrey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              RatingBarIndicator(
                                rating: comment['rating'].toDouble(),
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                itemCount: 5,
                                itemSize: 18.0,
                                direction: Axis.horizontal,
                              ),
                            ],
                          ),
                          trailing: Padding(
                            padding: const EdgeInsets.only(left: 0.0), 
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  comment['timestamp'].toString().substring(0, 16),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (isOwnComment) ...[
                                  const SizedBox(width: 0.0), // Khoảng cách giữa thời gian và nút xóa
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red[400],
                                      size: 24.0, // Tăng kích thước icon
                                    ),
                                    onPressed: () => _deleteComment(comment['docId']),
                                    tooltip: 'Xóa bình luận',
                                    splashRadius: 20.0,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
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