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
        '/bookOverview': (context) => const BookOverviewScreen(),
        '/favorites': (context) => const FavoritesScreen(), // お気に入り一覧画面を追加
        '/review': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as ReviewScreenArguments;
          return ReviewScreen(args: args);
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/book') {
          final args = settings.arguments as BookScreenArguments;
          return MaterialPageRoute(
            builder: (context) => BookScreen(args: args),
          );
        }
        return null;
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

  // 各タブの Navigator をオフステージに配置して状態を保持
  Widget _buildOffstageNavigator(int index) {
    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          WidgetBuilder builder;

          // ルート名に基づいて適切な画面を返す
          if (settings.name == '/bookOverview') {
            builder = (context) => const BookOverviewScreen();
          } else if (settings.name == '/book') {
            final args = settings.arguments as BookScreenArguments;
            builder =
                (context) => BookScreen(
                  args: args,
                  onDispose: () {
                    // BookScreen が破棄されたときに呼ばれるコールバック
                    if (mounted) {
                      setState(() {
                        _hideBottomNavigationBar = false;
                      });
                    }
                  },
                );

            // タブバーを非表示にするためのコールバックを設定
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hideBottomNavigationBar = true;
                });
              }
            });
          } else if (settings.name == '/review') {
            final args = settings.arguments as ReviewScreenArguments;
            builder = (context) => ReviewScreen(args: args);

            // タブバーを非表示にするためのコールバックを設定
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hideBottomNavigationBar = true;
                });
              }
            });
          } else {
            // デフォルトルート - タブバーを表示
            builder = (context) => _getTabScreen(index);

            // デフォルトルートに戻った場合、タブバーを表示するためのコールバックを設定
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _hideBottomNavigationBar) {
                setState(() {
                  _hideBottomNavigationBar = false;
                });
              }
            });
          }

          return MaterialPageRoute(
            builder: builder,
            settings: settings,
            // 画面遷移が完了した時に呼ばれるコールバック
            maintainState: true,
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      // 既に選択中の場合、Navigator のスタックをポップして先頭に戻す
      _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);

      // メニューを再表示
      if (_hideBottomNavigationBar) {
        setState(() {
          _hideBottomNavigationBar = false;
        });
      }
    } else {
      setState(() {
        _selectedIndex = index;
        // タブを切り替えた時、ボトムナビゲーションバーを再表示
        _hideBottomNavigationBar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final isFirstRouteInCurrentTab =
            !await _navigatorKeys[_selectedIndex].currentState!.maybePop();

        // 画面が戻ったとき、下部メニューを再表示
        if (!isFirstRouteInCurrentTab) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _hideBottomNavigationBar) {
              setState(() {
                _hideBottomNavigationBar = false;
              });
            }
          });
          return false;
        }

        if (isFirstRouteInCurrentTab) {
          // 現在のタブがルート画面の場合、最初のタブでなければそれに切り替え
          if (_selectedIndex != 0) {
            _onItemTapped(0);
            return false;
          }
        }
        // ハンドリングしない場合はシステムに任せる
        return isFirstRouteInCurrentTab;
      },
      child: Scaffold(
        // 各タブのNavigatorをStackで重ねる
        body: Stack(
          children: List.generate(4, (index) => _buildOffstageNavigator(index)),
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

  // BookScreenからの通知を受け取るためのメソッド
  void setBottomNavigationBarVisibility(bool isVisible) {
    if (_hideBottomNavigationBar != !isVisible) {
      setState(() {
        _hideBottomNavigationBar = !isVisible;
      });
    }
  }
}
