// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 各画面のインポート
import 'screens/home_screen.dart';
import 'screens/book_screen.dart';
import 'screens/book_overview_screen.dart';
import 'screens/my_page_screen.dart';
import 'screens/recommend_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/review_screen.dart'; // レビュー画面を追加
import 'screens/favorites_screen.dart'; // お気に入り一覧画面を追加

// リポジトリのインポート
import 'repositories/book_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦に固定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ステータスバーを透明にして背景画像を上まで表示できるようにする
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // ダークな背景に対して白いアイコン
    ),
  );

  // プリインストールされた本を初期化
  final bookRepository = BookRepository();
  await bookRepository.initializePreinstalledBooks();

  runApp(const MyApp());
}

/// アプリ全体のルート
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '「エホミル」大人が楽しめる絵本アプリ',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const MainPage(),
      routes: {
        // ここは /bookOverview, /favorites, /review など固定画面のルートを定義
        '/bookOverview': (context) => const BookOverviewScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/review': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as ReviewScreenArguments;
          return ReviewScreen(args: args);
        },
      },
    );
  }
}

/// 下部タブと各タブごとに Navigator を持つメイン画面
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _hideBottomNavigationBar = false;

  // BookScreenの表示状態を追跡する
  bool _isBookScreenActive = false;

  // 各タブごとに Navigator のキーを用意して状態を保持する
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // タブごとのルート画面を返す
  Widget _getTabScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const MyPageScreen();
      case 2:
        return const RecommendScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // タブ内の Navigator で画面遷移を制御
  Widget _buildOffstageNavigator(int index) {
    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          // ルート名に基づいて画面を返す
          if (settings.name == '/book') {
            // BottomNavigationBar を隠す
            setState(() {
              _hideBottomNavigationBar = true;
            });

            final args = settings.arguments as BookScreenArguments;

            // フェードアニメを実装した PageRouteBuilder
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return BookScreen(
                  args: args,
                  onDispose: () {
                    // BookScreen が破棄されたとき
                    if (mounted) {
                      setState(() {
                        _hideBottomNavigationBar = false;
                      });
                    }
                  },
                );
              },
              transitionDuration: const Duration(milliseconds: 500), // 0.5秒
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(
                  opacity: Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(animation),
                  child: child,
                );
              },
            );
          } else if (settings.name == '/') {
            // タブのメイン画面
            return MaterialPageRoute(
              builder: (context) => _getTabScreen(index),
              settings: settings,
            );
          } else if (settings.name == '/review') {
            // レビュー画面でもナビゲーションバーを非表示にしたい場合
            setState(() {
              _hideBottomNavigationBar = true;
            });
            final args = settings.arguments as ReviewScreenArguments;
            return MaterialPageRoute(
              builder: (context) => ReviewScreen(args: args),
              settings: settings,
            );
          } else if (settings.name == '/bookOverview') {
            return MaterialPageRoute(
              builder: (context) => const BookOverviewScreen(),
              settings: settings,
            );
          }

          // その他のルートが来たらデフォルトでタブ画面を返す
          return MaterialPageRoute(
            builder: (context) => _getTabScreen(index),
            settings: settings,
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      // 既に選択中の場合、スタックを先頭まで戻す
      _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
      // NavBar 再表示したければ
      setState(() {
        _hideBottomNavigationBar = false;
      });
    } else {
      // タブを切り替え
      setState(() {
        _selectedIndex = index;
        _hideBottomNavigationBar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "MainPage build called, _hideBottomNavigationBar = $_hideBottomNavigationBar",
    );

    return WillPopScope(
      onWillPop: () async {
        final isFirstRouteInCurrentTab =
            !await _navigatorKeys[_selectedIndex].currentState!.maybePop();

        // 画面が戻ったとき、下部メニューを再表示
        if (!isFirstRouteInCurrentTab) {
          setState(() {
            _hideBottomNavigationBar = false;
          });
          return false;
        }

        // 現在のタブがルート画面の場合、最初のタブでなければ切り替え
        if (isFirstRouteInCurrentTab) {
          if (_selectedIndex != 0) {
            _onItemTapped(0);
            return false;
          }
        }
        // ハンドリングしない場合はシステムに任せる
        return isFirstRouteInCurrentTab;
      },
      child: Scaffold(
        body: Stack(
          children: List.generate(4, (i) => _buildOffstageNavigator(i)),
        ),
        bottomNavigationBar:
            _hideBottomNavigationBar
                ? null
                : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  selectedItemColor: Colors.green,
                  unselectedItemColor: Colors.grey,
                  onTap: _onItemTapped,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.book),
                      label: 'えほん',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person),
                      label: 'My本棚',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.warehouse),
                      label: '倉庫',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings),
                      label: '設定',
                    ),
                  ],
                ),
      ),
    );
  }
}
