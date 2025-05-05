import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingCommentHandler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveRating(String filePath, int rating) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('saveRating: Người dùng chưa đăng nhập');
        throw Exception('Người dùng chưa đăng nhập');
      }
      final docId = filePath.replaceAll('/', '_').replaceAll('.', '_');
      print('saveRating: Lưu đánh giá cho filePath: $filePath, docId: $docId, user: ${user.uid}, rating: $rating');
      await _firestore
          .collection('ratings')
          .doc(docId)
          .collection('user_ratings')
          .doc(user.uid)
          .set({
        'displayName': user.displayName ?? 'Anonymous',
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('saveRating: Đánh giá đã được lưu');
    } catch (e) {
      print('saveRating: Lỗi lưu đánh giá: $e');
      throw Exception('Không thể lưu đánh giá: $e');
    }
  }

  Future<double> getAverageRating(String filePath) async {
    try {
      final docId = filePath.replaceAll('/', '_').replaceAll('.', '_');
      print('getAverageRating: Truy vấn ratings/$docId/user_ratings');
      final snapshot = await _firestore
          .collection('ratings')
          .doc(docId)
          .collection('user_ratings')
          .get();
      if (snapshot.docs.isEmpty) {
        print('getAverageRating: Không có đánh giá nào');
        return 0.0;
      }
      final total = snapshot.docs.fold<int>(0, (sum, doc) => sum + (doc.data()['rating'] as int));
      print('getAverageRating: Tổng: $total, Số đánh giá: ${snapshot.docs.length}, Trung bình: ${total / snapshot.docs.length}');
      return total / snapshot.docs.length;
    } catch (e) {
      print('getAverageRating: Lỗi lấy đánh giá trung bình: $e');
      return 0.0;
    }
  }

  Future<int> getUserRating(String filePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('getUserRating: Người dùng chưa đăng nhập');
        return 0;
      }
      final docId = filePath.replaceAll('/', '_').replaceAll('.', '_');
      print('getUserRating: Truy vấn ratings/$docId/user_ratings/${user.uid}');
      final doc = await _firestore
          .collection('ratings')
          .doc(docId)
          .collection('user_ratings')
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        print('getUserRating: Người dùng chưa đánh giá');
        return 0;
      }
      final rating = doc.data()?['rating'] as int? ?? 0;
      print('getUserRating: Đánh giá của người dùng: $rating');
      return rating;
    } catch (e) {
      print('getUserRating: Lỗi lấy đánh giá người dùng: $e');
      return 0;
    }
  }

  Future<void> saveComment(String filePath, String comment, int rating) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('saveComment: Người dùng chưa đăng nhập');
        throw Exception('Người dùng chưa đăng nhập');
      }
      final docId = filePath.replaceAll('/', '_').replaceAll('.', '_');
      print('saveComment: Lưu bình luận cho filePath: $filePath, docId: $docId, user: ${user.uid}, displayName: ${user.displayName}, comment: $comment, rating: $rating');
      await _firestore
          .collection('comments')
          .doc(docId)
          .collection('comment_list')
          .add({
        'userId': user.uid, // Lưu userId để kiểm tra khi xóa
        'displayName': user.displayName ?? 'Anonymous',
        'comment': comment,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('saveComment: Bình luận đã được lưu');
    } catch (e) {
      print('saveComment: Lỗi lưu bình luận: $e');
      throw Exception('Không thể lưu bình luận: $e');
    }
  }

  Future<void> deleteComment(String filePath, String commentDocId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('deleteComment: Người dùng chưa đăng nhập');
        throw Exception('Người dùng chưa đăng nhập');
      }
      final docId = filePath.replaceAll('/', '_').replaceAll('.', '_');
      print('deleteComment: Xóa bình luận filePath: $filePath, docId: $docId, commentDocId: $commentDocId');
      final doc = await _firestore
          .collection('comments')
          .doc(docId)
          .collection('comment_list')
          .doc(commentDocId)
          .get();
      if (!doc.exists || doc.data()?['userId'] != user.uid) {
        print('deleteComment: Không có quyền xóa bình luận');
        throw Exception('Bạn không có quyền xóa bình luận này');
      }
      await _firestore
          .collection('comments')
          .doc(docId)
          .collection('comment_list')
          .doc(commentDocId)
          .delete();
      print('deleteComment: Bình luận đã được xóa');
    } catch (e) {
      print('deleteComment: Lỗi xóa bình luận: $e');
      throw Exception('Không thể xóa bình luận: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getComments(String filePath) {
    final docId = filePath.replaceAll('/', '_').replaceAll('.', '_');
    print('getComments: Truy vấn comments/$docId/comment_list');
    return _firestore
        .collection('comments')
        .doc(docId)
        .collection('comment_list')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      print('getComments: Nhận ${snapshot.docs.length} bình luận');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('displayName') || !data.containsKey('comment')) {
          print('getComments: Dữ liệu không hợp lệ: $data');
          return {
            'docId': doc.id,
            'userId': '',
            'displayName': 'Unknown',
            'comment': 'Dữ liệu lỗi',
            'rating': 0,
            'timestamp': DateTime.now(),
          };
        }
        print('getComments: Bình luận - displayName: ${data['displayName']}, comment: ${data['comment']}, rating: ${data['rating']}');
        return {
          'docId': doc.id, // Lưu ID tài liệu để xóa
          'userId': data['userId'] as String? ?? '',
          'displayName': data['displayName'] as String,
          'comment': data['comment'] as String,
          'rating': data['rating'] as int? ?? 0,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    });
  }
}