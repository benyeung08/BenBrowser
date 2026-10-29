import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../data/models/user_account.dart';

/// 账号服务：Google / Microsoft 登录
///
/// 用 Supabase 统一处理两个渠道：OAuth 的 client id / secret 配在
/// Supabase 后台，客户端只需要项目 URL 和 publishable key，
/// 换渠道时不必改客户端代码。
///
/// **未配置时的行为**：[isReady] 为 false，所有方法都直接返回而不联网，
/// UI 会显示配置引导而不是报错。这样在填入真实值之前应用照常可用。
class AccountService {
  bool _initialized = false;
  String? _initError;

  /// 常量里是否已填了真实值
  bool get isConfigured => CloudConfig.isConfigured;

  /// 真正可用：既配置了，也初始化成功了
  bool get isReady => isConfigured && _initialized;

  /// 初始化失败的原因（供 UI 展示），正常情况为 null
  String? get initError => _initError;

  /// 初始化 Supabase。未配置时直接返回，不抛异常。
  Future<void> initialize() async {
    if (!isConfigured) return;
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        publishableKey: CloudConfig.supabasePublishableKey,
      );
      _initialized = true;
    } catch (e) {
      // 配错 key、网络不通都不该让应用起不来
      _initialized = false;
      _initError = e.toString();
    }
  }

  /// 内部访问客户端；未完成初始化时为 null
  SupabaseClient? get _client => isReady ? Supabase.instance.client : null;

  /// 供 [SyncService] 使用。类型上依赖 Supabase，换来的是
  /// 同步层不用反射/dynamic 去够私有成员，可读性更好。
  SupabaseClient? get client => _client;

  /// 当前登录用户的 id；未登录为 null
  String? get userId => _client?.auth.currentUser?.id;

  UserAccount? get currentAccount {
    final user = _client?.auth.currentUser;
    return user == null ? null : _fromUser(user);
  }

  /// 登录状态变化流。未配置时返回空流，UI 不会因此报错。
  Stream<UserAccount?> get authStateChanges {
    final client = _client;
    if (client == null) return const Stream<UserAccount?>.empty();
    return client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user == null ? null : _fromUser(user);
    });
  }

  /// 发起 OAuth 登录。
  ///
  /// 桌面端与移动端的回调方式不同：Android 走自定义 scheme 深链，
  /// 桌面端交给 Supabase 处理（redirectTo 传 null）。
  /// 返回 false 表示未配置或启动登录失败。
  Future<bool> signIn(AccountProvider provider) async {
    final client = _client;
    if (client == null) return false;

    final oauthProvider = switch (provider) {
      AccountProvider.google => OAuthProvider.google,
      AccountProvider.microsoft => OAuthProvider.azure,
    };

    try {
      return await client.auth.signInWithOAuth(
        oauthProvider,
        redirectTo: Platform.isAndroid ? CloudConfig.oauthRedirectUrl : null,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.auth.signOut();
    } catch (_) {
      // 登出失败也当作已登出处理，避免卡在中间态
    }
  }

  /// 把 Supabase 的 User 映射成我们自己的模型
  UserAccount _fromUser(User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final provider = _detectProvider(user);

    return UserAccount(
      id: user.id,
      provider: provider,
      email: user.email,
      displayName: _firstNonEmpty([
        meta['full_name'],
        meta['name'],
        meta['preferred_username'],
      ]),
      avatarUrl: _firstNonEmpty([
        meta['avatar_url'],
        meta['picture'],
      ]),
    );
  }

  /// Google 和 Microsoft 返回的 metadata 字段名不一样，
  /// 用 app_metadata 里的 provider 判断最可靠。
  AccountProvider _detectProvider(User user) {
    final appMeta = user.appMetadata;
    final raw = (appMeta['provider'] ?? '').toString().toLowerCase();
    if (raw.contains('azure') || raw.contains('microsoft')) {
      return AccountProvider.microsoft;
    }
    return AccountProvider.google;
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}
