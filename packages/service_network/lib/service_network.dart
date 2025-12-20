library service_network;

export 'src/api_response.dart';
export 'src/app_exception.dart';
export 'src/network_client.dart';
export 'src/network_config.dart';
export 'src/network_types.dart';

/// 使用示例：
/// ```dart
/// final client = NetworkClient(
///   config: NetworkConfig(
///     baseUrl: 'https://api.example.com',
///     tokenProvider: () async => 'your_token',
///   ),
/// );
///
/// // Repository 层调用，结合泛型解析：
/// class UserRepository {
///   UserRepository(this._client);
///
///   final NetworkClient _client;
///
///   Future<User> fetchProfile() {
///     return _client.get<User>(
///       '/user/profile',
///       parser: (json) => User.fromJson(json as Map<String, dynamic>),
///     );
///   }
/// }
/// ```
