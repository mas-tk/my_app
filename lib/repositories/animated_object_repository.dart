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
      behavior:
          ObjectAnimationBehavior
              .inPlace, // AnimationBehavior から ObjectAnimationBehavior に変更
      expandRatio: 1.2,
    ),
    // 他のアニメーションオブジェクトを追加
    // 例:
    /*
    'obj4': AnimatedObjectInfo(
      objectId: 'obj4',
      name: '金のねこフィギア',
      staticImagePath: 'assets/objects/neko_kin.png',
      animatedAssetPath: 'assets/animations/neko_kin.gif',
      animationType: AnimationType.gif,
      behavior: ObjectAnimationBehavior.climbShelf,
      expandRatio: 1.5,
    ),
    */
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
