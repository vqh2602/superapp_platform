/// Mô tả Manifest của Mini App (Mini App Manifest Descriptor).
///
/// Định nghĩa toàn bộ thông tin siêu dữ liệu (metadata) của Mini App: mã ứng dụng id,
/// tên, mô tả, phiên bản, URL khởi chạy (entryUrl), danh sách quyền hạn (capabilities),
/// loại runtime (web hoặc no-code schema) và danh mục phân loại.
class MiniAppManifest {
  /// Mã định danh duy nhất của Mini App (vd: 'sample_store', 'sdk_playground')
  final String id;
  /// Tên hiển thị của ứng dụng
  final String name;
  /// Đoạn mô tả tóm tắt chức năng ứng dụng
  final String description;
  /// Phiên bản ứng dụng (SemVer, vd: '1.0.0')
  final String version;
  /// Đường dẫn icon hoặc URL ảnh đại diện
  final String icon;
  /// URL trang web điểm vào của Mini App
  final String entryUrl;
  /// Nguồn chạy là asset nội bộ hay tải qua mạng
  final bool isAsset;
  /// Danh sách các quyền capability được phép sử dụng
  final List<String> capabilities;
  /// Kiểu môi trường thực thi: 'web' (Web Mini App) hoặc 'schema' (No-Code Schema)
  final String appRuntimeType;
  /// Danh mục phân loại (vd: 'Tiện ích', 'Mua sắm', 'Trò chơi')
  final String category;
  /// Trạng thái phát hành của ứng dụng trên hệ thống Backend
  final String status;
  /// Phiên bản của schema No-Code (nếu là schema app)
  final int schemaVersion;
  /// Dữ liệu cấu trúc No-Code JSON schema (nếu có)
  final Map<String, dynamic>? schema;
  /// Thời điểm cập nhật phiên bản gần nhất
  final DateTime? updatedAt;

  const MiniAppManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.icon,
    required this.entryUrl,
    this.isAsset = false,
    required this.capabilities,
    this.appRuntimeType = 'web',
    this.category = 'General',
    this.status = 'PUBLISHED',
    this.schemaVersion = 1,
    this.schema,
    this.updatedAt,
  });

  /// Kiểm tra xem ứng dụng có chạy bằng cơ chế No-Code Schema Runtime hay không
  bool get isSchemaApp => appRuntimeType == 'schema';

  /// Kiểm tra xem ứng dụng có chạy bằng cơ chế Web HTML5 thông thường hay không
  bool get isWebApp => appRuntimeType == 'web';

  /// Khởi tạo [MiniAppManifest] từ Map JSON trả về bởi API Backend
  factory MiniAppManifest.fromJson(Map<String, dynamic> json) {
    return MiniAppManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      icon: json['icon'] as String? ?? 'code',
      entryUrl: json['entryUrl'] as String? ?? '',
      isAsset: json['isAsset'] as bool? ?? false,
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      appRuntimeType: json['runtimeType'] as String? ?? 'web',
      category: json['category'] as String? ?? 'General',
      status: json['status'] as String? ?? 'PUBLISHED',
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      schema: json['schema'] as Map<String, dynamic>?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'icon': icon,
    'entryUrl': entryUrl,
    'isAsset': isAsset,
    'capabilities': capabilities,
    'runtimeType': appRuntimeType,
    'category': category,
    'status': status,
    'schemaVersion': schemaVersion,
    if (schema != null) 'schema': schema,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}
