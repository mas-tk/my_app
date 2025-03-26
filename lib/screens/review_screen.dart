// lib/screens/review_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_models.dart';

// レビューコメントモデル
class ReviewComment {
  final String username;
  final double rating;
  final String comment;
  final DateTime date;

  ReviewComment({
    required this.username,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

class ReviewScreenArguments {
  final String bookId;
  final String title;
  final bool isFavorite;
  final double userRating;

  ReviewScreenArguments({
    required this.bookId,
    required this.title,
    this.isFavorite = false,
    this.userRating = 0.0,
  });
}

class ReviewScreen extends StatefulWidget {
  final ReviewScreenArguments args;

  const ReviewScreen({Key? key, required this.args}) : super(key: key);

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isFavorite = false;
  double _userRating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  List<ReviewComment> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.args.isFavorite;
    _userRating = widget.args.userRating;

    // 初期化を非同期で安全に行う
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
      _loadUserComment();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ユーザーの以前のコメントを読み込む
  Future<void> _loadUserComment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedComment = prefs.getString('comment_${widget.args.bookId}');

      if (savedComment != null && savedComment.isNotEmpty) {
        setState(() {
          _commentController.text = savedComment;
        });
      }
    } catch (e) {
      print('Error loading user comment: $e');
    }
  }

  // レビューを読み込む
  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 実際の実装では API からレビューを読み込む
      // ここではデモ用にダミーデータを設定
      setState(() {
        _reviews = [
          ReviewComment(
            username: '田中さん',
            rating: 4.5,
            comment: 'とても素敵な絵本です。子供も大喜びでした。',
            date: DateTime.now().subtract(const Duration(days: 5)),
          ),
          ReviewComment(
            username: '佐藤さん',
            rating: 5.0,
            comment: 'ストーリーも絵も素晴らしい。何度も読み返しています。',
            date: DateTime.now().subtract(const Duration(days: 10)),
          ),
          ReviewComment(
            username: '鈴木さん',
            rating: 3.5,
            comment: '面白いですが、もう少し長いとよかったかも。',
            date: DateTime.now().subtract(const Duration(days: 15)),
          ),
        ];
      });
    } catch (e) {
      print('Error loading reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // お気に入り状態を切り替え
  Future<void> _toggleFavorite() async {
    try {
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // SharedPreferences でお気に入り状態を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('favorite_${widget.args.bookId}', _isFavorite);
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  // 評価を保存
  Future<void> _saveRating() async {
    try {
      // SharedPreferences で評価を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('rating_${widget.args.bookId}', _userRating);

      // コメントも保存する場合
      if (_commentController.text.isNotEmpty) {
        await prefs.setString(
          'comment_${widget.args.bookId}',
          _commentController.text,
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('評価を保存しました')));

      // 閉じる（オプション）
      // Navigator.pop(context);
    } catch (e) {
      print('Error saving rating: $e');
    }
  }

  // レビューアイテムのウィジェット
  Widget _buildReviewItem(ReviewComment review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDate(review.date),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 星評価表示
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < review.rating.floor()
                      ? Icons.star
                      : (index < review.rating.ceil() &&
                          index >= review.rating.floor())
                      ? Icons.star_half
                      : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                );
              }),
              const SizedBox(width: 8),
              Text(
                review.rating.toString(),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 日付のフォーマット
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: Text(
          widget.args.title,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : Container(
                color: Colors.black.withOpacity(0.85),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 他のユーザーのレビュー
                        const Text(
                          'みんなの評価',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // レビューリスト
                        ..._reviews.map((review) => _buildReviewItem(review)),

                        const SizedBox(height: 32),
                        const Divider(color: Colors.white30),
                        const SizedBox(height: 24),

                        // 自分の評価
                        const Text(
                          'あなたの評価',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 星評価
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                _userRating > index
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 36,
                              ),
                              onPressed: () {
                                setState(() {
                                  _userRating = index + 1.0;
                                });
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 16),

                        // コメント入力
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'この絵本についてのコメントを書いてください',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 評価保存ボタン
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveRating,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              '評価を保存する',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Divider(color: Colors.white30),
                        const SizedBox(height: 24),

                        // お気に入りセクション
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // お気に入りボタン
                            ElevatedButton.icon(
                              icon: Icon(
                                _isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorite ? Colors.red : Colors.white,
                              ),
                              label: Text(
                                _isFavorite ? 'お気に入り済み' : 'お気に入りに追加',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isFavorite
                                        ? Colors.redAccent.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _toggleFavorite,
                            ),

                            // 閉じるボタン
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              label: const Text(
                                '絵本に戻る',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
