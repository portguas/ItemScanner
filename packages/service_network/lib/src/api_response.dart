/// Generic response model: { "code": 200, "message": "success", "data": T }
typedef JsonParser<T> = T Function(Object? json);

class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  bool get success => code == 200;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    JsonParser<T>? parser,
  }) {
    final rawData = json['data'];
    final T? parsedData = parser != null
        ? parser(rawData)
        : rawData is T
            ? rawData
            : rawData as T?;

    return ApiResponse(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: parsedData,
    );
  }
}
