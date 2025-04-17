// lib/repositories/animated_object_repository.dart
import '../models/animated_object_models.dart';

class AnimatedObjectRepository {
  // シングルトンパターン
  static final AnimatedObjectRepository _instance =
      AnimatedObjectRepository._internal();
  factory AnimatedObjectRepository() => _instance;
  AnimatedObjectRepository._internal();

  // デコレーションオブジェクトIDとそのアニメーション情報のマッピング
  final Map<String, AnimatedObjectInfo> _animatedObjectsMap = {
    'obj1': AnimatedObjectInfo(
      objectId: 'obj1',
      name: 'ねこのフィギア',
      staticImagePath: 'assets/objects/neko.png',
      animatedAssetPath: 'assets/animations/neko.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.inPlace,
      expandRatio: 1.2,
    ),
    // 他のアニメーションオブジェクトを追加
    'obj4': AnimatedObjectInfo(
      objectId: 'obj4',
      name: '金のねこフィギア',
      staticImagePath: 'assets/objects/neko_kin.png',
      animatedAssetPath: 'assets/animations/neko_kin.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.climbShelf,
      expandRatio: 1.5,
    ),
    'obj6': AnimatedObjectInfo(
      objectId: 'obj6',
      name: '本の住人',
      staticImagePath: 'assets/objects/jyunin.png',
      animatedAssetPath: 'assets/animations/jyunin.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.walkAround,
      expandRatio: 1.3,
    ),
    'obj2': AnimatedObjectInfo(
      objectId: 'obj2',
      name: '丸いサボテン',
      staticImagePath: 'assets/objects/saboten_maru.png',
      animatedAssetPath: 'assets/animations/saboten_maru.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.inPlace,
      expandRatio: 1.2,
    ),
    'obj3': AnimatedObjectInfo(
      objectId: 'obj3',
      name: '天球儀とドラゴン',
      staticImagePath: 'assets/objects/tenkyugi.png',
      animatedAssetPath: 'assets/animations/tenkyugi.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.inPlace,
      expandRatio: 1.2,
    ),
    'obj5': AnimatedObjectInfo(
      objectId: 'obj5',
      name: '縦長のサボテン',
      staticImagePath: 'assets/objects/saboten_nagai.png',
      animatedAssetPath: 'assets/animations/saboten_nagai.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.inPlace,
      expandRatio: 1.2,
    ),
  };

  // オブジェクトのアニメーション情報を取得
  AnimatedObjectInfo? getAnimationForObject(String objectId) {
    return _animatedObjectsMap[objectId];
  }

  // オブジェクトがアニメーションをサポートしているかチェック
  bool hasAnimation(String objectId) {
    return _animatedObjectsMap.containsKey(objectId);
  }
}
