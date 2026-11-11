/// Mô hình đối tượng lưu trữ bảo mật (Secure Storage Entry).
///
/// Chứa thông tin về khóa, giá trị, domain, appId sở hữu, thời gian tạo/cập nhật,
/// trạng thái mã hóa và cấp độ an toàn phần cứng (Keychain hoặc Keystore).
class SecureStorageEntry {
  /// Khóa định danh của mục dữ liệu
  final String key;
  /// Giá trị được lưu trữ
  final String value;
  /// Vùng miền phân loại (vd: 'default', 'auth')
  final String domain;
  /// Mã định danh Mini App sở hữu
  final String appId;
  /// Thời điểm tạo
  final DateTime createdAt;
  /// Thời điểm cập nhật gần nhất
  final DateTime updatedAt;
  /// Dữ liệu có được mã hóa an toàn hay không
  final bool isEncrypted;
  /// Cấp độ an ninh phần cứng lưu trữ
  final String securityLevel;

  const SecureStorageEntry({
    required this.key,
    required this.value,
    required this.domain,
    required this.appId,
    required this.createdAt,
    required this.updatedAt,
    this.isEncrypted = true,
    this.securityLevel = 'KEYCHAIN_OR_KEYSTORE',
  });

  /// Chuyển đổi dữ liệu thành Map JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'domain': domain,
      'appId': appId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isEncrypted': isEncrypted,
      'securityLevel': securityLevel,
    };
  }

  /// Tạo bản sao với giá trị và thời gian cập nhật mới
  SecureStorageEntry copyWith({
    String? value,
    DateTime? updatedAt,
  }) {
    return SecureStorageEntry(
      key: key,
      value: value ?? this.value,
      domain: domain,
      appId: appId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isEncrypted: isEncrypted,
      securityLevel: securityLevel,
    );
  }
}
