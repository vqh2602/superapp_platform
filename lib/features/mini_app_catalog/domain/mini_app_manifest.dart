/// Manifest descriptor for Mini Apps registered in the Super App.
class MiniAppManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final String icon;
  final String entryUrl;
  final bool isAsset;
  final List<String> capabilities;

  const MiniAppManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.icon,
    required this.entryUrl,
    this.isAsset = true,
    required this.capabilities,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'icon': icon,
    'entryUrl': entryUrl,
    'isAsset': isAsset,
    'capabilities': capabilities,
  };
}
