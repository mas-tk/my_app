// lib/bloc/book_download_bloc.dart
import 'dart:async';
import '../models/book_models.dart';
import '../repositories/book_repository.dart';
import '../services/storage_manager.dart'; // StorageManager を直接インポート

enum DownloadStatus { idle, downloading, completed, failed }

class BookDownloadState {
  final String bookId;
  final DownloadStatus status;
  final double progress;
  final String? error;

  BookDownloadState({
    required this.bookId,
    required this.status,
    this.progress = 0.0,
    this.error,
  });

  BookDownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
  }) {
    return BookDownloadState(
      bookId: this.bookId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class BookDownloadBloc {
  final BookRepository _repository = BookRepository();
  final StorageManager _storageManager = StorageManager(); // 直接インスタンス化

  // 各本のダウンロード状態を保持
  final Map<String, StreamController<BookDownloadState>> _controllers = {};

  // シングルトンパターン
  static final BookDownloadBloc _instance = BookDownloadBloc._internal();
  factory BookDownloadBloc() => _instance;
  BookDownloadBloc._internal();

  // 指定した本のダウンロード状態ストリームを取得
  Stream<BookDownloadState> getDownloadStateStream(String bookId) {
    if (!_controllers.containsKey(bookId)) {
      _controllers[bookId] = StreamController<BookDownloadState>.broadcast();

      // 初期状態を発行
      _repository.isBookDownloaded(bookId).then((isDownloaded) {
        final initialStatus =
            isDownloaded ? DownloadStatus.completed : DownloadStatus.idle;
        _controllers[bookId]!.add(
          BookDownloadState(
            bookId: bookId,
            status: initialStatus,
            progress: isDownloaded ? 1.0 : 0.0,
          ),
        );
      });
    }

    return _controllers[bookId]!.stream;
  }

  // 本のダウンロードを開始
  Future<void> downloadBook(String bookId) async {
    if (!_controllers.containsKey(bookId)) {
      getDownloadStateStream(bookId);
    }

    final controller = _controllers[bookId]!;

    // すでにダウンロード中なら何もしない
    final currentState = await controller.stream.first;
    if (currentState.status == DownloadStatus.downloading) {
      return;
    }

    // ダウンロード開始状態を発行
    controller.add(
      BookDownloadState(
        bookId: bookId,
        status: DownloadStatus.downloading,
        progress: 0.0,
      ),
    );

    try {
      // 本データを取得
      final book = await _repository.getBookById(bookId);
      if (book == null) {
        throw Exception('Book not found');
      }

      // 総アセット数を計算
      int totalAssets = 1; // カバー画像
      if (book.pages != null) {
        totalAssets += book.pages!.length * 2; // 各ページの2つの画像
      }
      if (book.audio != null) {
        totalAssets += book.audio!.tracks.length; // 音声トラック
      }

      int downloadedAssets = 0;

      // カバー画像をダウンロード
      await _storageManager.downloadAsset(book.coverAssetPath);
      downloadedAssets++;
      controller.add(
        BookDownloadState(
          bookId: bookId,
          status: DownloadStatus.downloading,
          progress: downloadedAssets / totalAssets,
        ),
      );

      // ページ画像をダウンロード
      if (book.pages != null) {
        for (var page in book.pages!) {
          await _storageManager.downloadAsset(page.baseImage);
          downloadedAssets++;
          controller.add(
            BookDownloadState(
              bookId: bookId,
              status: DownloadStatus.downloading,
              progress: downloadedAssets / totalAssets,
            ),
          );

          await _storageManager.downloadAsset(page.textImage);
          downloadedAssets++;
          controller.add(
            BookDownloadState(
              bookId: bookId,
              status: DownloadStatus.downloading,
              progress: downloadedAssets / totalAssets,
            ),
          );
        }
      }

      // 音声トラックをダウンロード
      if (book.audio != null) {
        for (var track in book.audio!.tracks) {
          await _storageManager.downloadAsset(track.assetPath);
          downloadedAssets++;
          controller.add(
            BookDownloadState(
              bookId: bookId,
              status: DownloadStatus.downloading,
              progress: downloadedAssets / totalAssets,
            ),
          );
        }
      }

      // 本をダウンロード済みとしてマーク
      await _storageManager.markBookAsDownloaded(bookId);

      // 完了状態を発行
      controller.add(
        BookDownloadState(
          bookId: bookId,
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      );
    } catch (e) {
      // 失敗状態を発行
      controller.add(
        BookDownloadState(
          bookId: bookId,
          status: DownloadStatus.failed,
          error: e.toString(),
        ),
      );
    }
  }

  // ダウンロード済みの本を削除
  Future<void> deleteDownloadedBook(String bookId) async {
    if (!_controllers.containsKey(bookId)) {
      getDownloadStateStream(bookId);
    }

    final controller = _controllers[bookId]!;

    try {
      final success = await _repository.deleteDownloadedBook(bookId);

      if (success) {
        controller.add(
          BookDownloadState(
            bookId: bookId,
            status: DownloadStatus.idle,
            progress: 0.0,
          ),
        );
      }
    } catch (e) {
      print('Error deleting downloaded book: $e');
    }
  }

  // リソース解放
  void dispose(String bookId) {
    if (_controllers.containsKey(bookId)) {
      _controllers[bookId]!.close();
      _controllers.remove(bookId);
    }
  }

  void disposeAll() {
    for (var controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
