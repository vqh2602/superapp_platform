class SecureStorageEntry {
  final String key;
  final String value;
  final String domain;
  final String appId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEncrypted;
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
