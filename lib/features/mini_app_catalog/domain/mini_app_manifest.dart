/// Manifest descriptor for Mini Apps registered in the Super App.
/// Supports both Type A (existing Web Mini Apps) and Type B (No-Code Schema Mini Apps).
class MiniAppManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final String icon;
  final String entryUrl;
  final bool isAsset;
  final List<String> capabilities;
  final String appRuntimeType; // 'web' | 'schema'
  final String category;
  final String status; // 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'PUBLISHED' | 'UNPUBLISHED' | 'SUSPENDED'
  final int schemaVersion;
  final Map<String, dynamic>? schema;
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

  bool get isSchemaApp => appRuntimeType == 'schema';
  bool get isWebApp => appRuntimeType == 'web';

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
