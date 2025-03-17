import 'package:flutter/material.dart';
class TheoryScreen extends StatelessWidget{
  const TheoryScreen ({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Lý thuyết",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Quay lại HomeScreen
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 20),
            _buildTheoryOption(
              context,
              "Lý thuyết về cách xác định phím đàn",
              "Học cách nhận biết và xác định các phím trên đàn piano.",
            ),
            _buildTheoryOption(
              context,
              "Hợp âm",
              "Tìm hiểu về các loại hợp âm và cách chơi chúng.",
            ),
            // Thêm các lựa chọn khác nếu cần
          ],
        ),
      ),
    );
  }

  Widget _buildTheoryOption(BuildContext context, String title, String description) {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: Colors.grey),
        ),
        onTap: () {
          // Điều hướng đến trang chi tiết (có thể mở rộng sau)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Đang phát triển: $title")),
          );
        },
      ),
    );
  }
}