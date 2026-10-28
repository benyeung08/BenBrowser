/// 登录渠道
enum AccountProvider {
  google,
  microsoft;

  String get label => switch (this) {
        AccountProvider.google => 'Google',
        AccountProvider.microsoft => 'Microsoft',
      };

  /// 显示在按钮上的简短提示
  String get hint => switch (this) {
        AccountProvider.google => '使用 Google 账号登录',
        AccountProvider.microsoft => '使用 Microsoft 账号登录',
      };
}

/// 已登录账号的展示信息
///
/// 刻意不依赖任何后端 SDK 的类型：这样即便后端换成别的方案，
/// 模型和 UI 都不用跟着改，只需替换 [AccountService] 的实现。
class UserAccount {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final AccountProvider provider;

  const UserAccount({
    required this.id,
    required this.provider,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  /// 头像和邮箱都可能拿不到（取决于授权范围），退化为首字母
  ///
  /// 这里刻意用 substring 而不是 characters 包：后者需要额外声明依赖，
  /// 为一个首字母引入依赖不值得；账号名以 BMP 字符开头的现实概率足够高。
  String get initial {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name.substring(0, 1);
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail.substring(0, 1);
    return '?';
  }

  String get title => (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : (email ?? '已登录');

  UserAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    AccountProvider? provider,
  }) =>
      UserAccount(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        provider: provider ?? this.provider,
      );

  @override
  String toString() => 'UserAccount($provider, $email)';
}
