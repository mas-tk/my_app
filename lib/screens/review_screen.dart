// lib/screens/review_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_models.dart';
import '../models/review_models.dart';
import '../repositories/review_repository.dart';
import '../repositories/coin_repository.dart';

// ソート方法の列挙型
enum SortMethod {
  byLikes, // いいね順
  byDate, // 投稿順
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

  // ソート方法の状態変数
  SortMethod _currentSortMethod = SortMethod.byLikes;

  // フォーカスノード
  final FocusNode _commentFocusNode = FocusNode();

  // リポジトリ
  final ReviewRepository _reviewRepository = ReviewRepository();
  final CoinRepository _coinRepository = CoinRepository();

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
    _commentFocusNode.dispose();
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
      // ReviewRepositoryからレビューを読み込む
      final reviews = await _reviewRepository.getReviewsForBook(
        widget.args.bookId,
      );

      setState(() {
        _reviews = reviews;
        // ソートを適用
        _sortReviews();
      });
    } catch (e) {
      print('Error loading reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // レビューをソートする
  void _sortReviews() {
    if (_currentSortMethod == SortMethod.byLikes) {
      // いいね数でソート（降順）
      _reviews.sort((a, b) => b.likes.compareTo(a.likes));
    } else {
      // 投稿日時でソート（新しい順）
      _reviews.sort((a, b) => b.date.compareTo(a.date));
    }
  }

  // ソート方法を切り替える
  void _toggleSortMethod() {
    setState(() {
      _currentSortMethod =
          _currentSortMethod == SortMethod.byLikes
              ? SortMethod.byDate
              : SortMethod.byLikes;
      _sortReviews();
    });
  }

  // いいねを切り替える
  Future<void> _toggleLike(int index) async {
    // レビューリポジトリで処理を実行
    final success = await _reviewRepository.toggleLike(
      widget.args.bookId,
      index,
    );

    if (success) {
      // データを再読み込み
      await _loadReviews();
    }
  }

  // SNSシェア機能
  Future<void> _shareToSNS() async {
    try {
      // ここでは実際のSNSシェア機能の代わりにスナックバーを表示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SNSにシェアしました！コインを獲得しました！')));

      // コインを付与
      await _coinRepository.earnCoins(
        100, // 獲得コイン数
        'share', // タイプ
        '${widget.args.title}をSNSでシェアしました', // 説明
      );
    } catch (e) {
      print('Error sharing to SNS: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('シェアに失敗しました')));
    }
  }

  // コメントを保存
  Future<void> _saveComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コメントを入力してください')));
      return;
    }

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

      // 新しいレビューを作成
      final newReview = ReviewComment(
        username: 'あなた', // ユーザー名
        rating: _userRating,
        comment: _commentController.text,
        date: DateTime.now(),
        likes: 0,
        isLiked: false,
      );

      // リポジトリにレビューを追加
      final success = await _reviewRepository.addReview(
        widget.args.bookId,
        newReview,
      );

      if (success) {
        // データを再読み込み
        await _loadReviews();

        // テキストフィールドをクリア
        setState(() {
          _commentController.clear();
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('コメントを投稿しました')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('コメントの保存に失敗しました')));
      }
    } catch (e) {
      print('Error saving comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コメントの保存に失敗しました')));
    }
  }

  // レビューアイテムのウィジェット
  Widget _buildReviewItem(ReviewComment review, int index) {
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
              ...List.generate(5, (i) {
                return Icon(
                  i < review.rating.floor()
                      ? Icons.star
                      : (i < review.rating.ceil() && i >= review.rating.floor())
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // いいねボタン
              GestureDetector(
                onTap: () => _toggleLike(index),
                child: Row(
                  children: [
                    Icon(
                      review.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: review.isLiked ? Colors.blue : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.likes.toString(),
                      style: TextStyle(
                        color: review.isLiked ? Colors.blue : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return GestureDetector(
      // 左から右へのスワイプ検出で画面を閉じる
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          // 右方向へのスワイプ（左から右）
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
          title: Text(
            widget.args.title,
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // タイトルが長い場合は省略
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white), // ←に変更
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : Column(
                  children: [
                    // ソート切り替えセクション
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'みんなのコメント',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          // ソート切り替えボタン
                          TextButton.icon(
                            onPressed: _toggleSortMethod,
                            icon: Icon(
                              _currentSortMethod == SortMethod.byLikes
                                  ? Icons.thumb_up
                                  : Icons.access_time,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: Text(
                              _currentSortMethod == SortMethod.byLikes
                                  ? 'いいね順'
                                  : '投稿順',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.3),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // レビューリスト - 下部にパディングを入れてSNSシェアボタンが重ならないように
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 90, // 下部に余白を追加
                        ),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          return _buildReviewItem(_reviews[index], index);
                        },
                      ),
                    ),

                    // 自分の評価とコメント入力部分（固定部分）
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, -3),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.only(
                        top: 12,
                        left: 16,
                        right: 16,
                        // キーボードの高さに合わせてパディングを調整
                        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 星評価とSNSシェアボタンを横に並べる
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 星評価
                              Row(
                                children: List.generate(5, (index) {
                                  return IconButton(
                                    icon: Icon(
                                      _userRating > index
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _userRating = index + 1.0;
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  );
                                }),
                              ),

                              // SNSシェアボタン
                              GestureDetector(
                                onTap: _shareToSNS,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade600,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.share,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'シェアする',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // コメント入力
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _commentFocusNode,
                                  maxLines: null,
                                  minLines: 1,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'コメントを入力...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 送信ボタン
                              IconButton(
                                onPressed: _saveComment,
                                icon: Icon(Icons.send, color: Colors.amber),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.amber.withOpacity(
                                    0.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // コメント入力下のコイン獲得ヒントテキスト
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Center(
                              child: Text(
                                'SNSでシェアすると100コインゲット！',
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
