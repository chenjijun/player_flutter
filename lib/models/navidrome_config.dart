class NavidromeConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String salt;
  final String token;

  NavidromeConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.salt = '',
    this.token = '',
  });

  factory NavidromeConfig.fromJson(Map<String, dynamic> json) {
    return NavidromeConfig(
      serverUrl: json['serverUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'salt': salt,
      'token': token,
    };
  }
  
  // 创建一个不包含密码的副本用于显示
  NavidromeConfig copyWithoutPassword() {
    return NavidromeConfig(
      serverUrl: serverUrl,
      username: username,
      password: '', // 不保存密码
      salt: salt,
      token: token,
    );
  }
  
  // 创建一个用于持久化存储的副本
  NavidromeConfig copyForStorage() {
    return NavidromeConfig(
      serverUrl: serverUrl,
      username: username,
      password: '', // 不在本地存储明文密码，除非用户选择保存
      salt: salt,
      token: token,
    );
  }
}