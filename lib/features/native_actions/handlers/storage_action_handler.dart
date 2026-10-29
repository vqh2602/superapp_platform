import '../../../../core/errors/bridge_error.dart';
import '../../storage/data/mock_secure_storage_repository.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class StorageSetSecureItemHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageSetSecureItemHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.setSecureItem';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final key = payload['key']?.toString();
    if (key == null || key.isEmpty) {
      throw BridgeError.invalidParams('Key is required for secure storage');
    }

    final dynamic rawValue = payload['value'];
    if (rawValue == null) {
      throw BridgeError.invalidParams('Value is required for secure storage');
    }

    final value = rawValue is String ? rawValue : rawValue.toString();
    final domain = (payload['domain']?.toString().isNotEmpty ?? false)
        ? payload['domain'].toString()
        : 'default';

    return await secureStorageRepo.setItem(
      appId: context.appId,
      key: key,
      value: value,
      domain: domain,
    );
  }
}

class StorageGetSecureItemHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageGetSecureItemHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.getSecureItem';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final key = payload['key']?.toString();
    if (key == null || key.isEmpty) {
      throw BridgeError.invalidParams('Key is required to retrieve secure storage item');
    }

    final domain = (payload['domain']?.toString().isNotEmpty ?? false)
        ? payload['domain'].toString()
        : 'default';

    return await secureStorageRepo.getItem(
      appId: context.appId,
      key: key,
      domain: domain,
    );
  }
}

class StorageRemoveSecureItemHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageRemoveSecureItemHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.removeSecureItem';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final key = payload['key']?.toString();
    if (key == null || key.isEmpty) {
      throw BridgeError.invalidParams('Key is required to remove secure storage item');
    }

    final domain = (payload['domain']?.toString().isNotEmpty ?? false)
        ? payload['domain'].toString()
        : 'default';

    return await secureStorageRepo.removeItem(
      appId: context.appId,
      key: key,
      domain: domain,
    );
  }
}

class StorageClearHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageClearHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.clear';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final domain = payload['domain']?.toString();
    return await secureStorageRepo.clear(
      appId: context.appId,
      domain: (domain != null && domain.isNotEmpty) ? domain : null,
    );
  }
}

class StorageGetAllHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageGetAllHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.getAll';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final domain = (payload['domain']?.toString().isNotEmpty ?? false)
        ? payload['domain'].toString()
        : 'default';

    return await secureStorageRepo.getAll(
      appId: context.appId,
      domain: domain,
    );
  }
}

class StorageSetCredentialsHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageSetCredentialsHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.setCredentials';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final domain = payload['domain']?.toString();
    final username = payload['username']?.toString();
    final password = payload['password']?.toString();

    if (domain == null || domain.isEmpty) {
      throw BridgeError.invalidParams('domain is required for credentials storage');
    }
    if (username == null || username.isEmpty) {
      throw BridgeError.invalidParams('username is required for credentials storage');
    }
    if (password == null || password.isEmpty) {
      throw BridgeError.invalidParams('password is required for credentials storage');
    }

    return await secureStorageRepo.setCredentials(
      appId: context.appId,
      domain: domain,
      username: username,
      password: password,
    );
  }
}

class StorageGetCredentialsHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageGetCredentialsHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.getCredentials';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final domain = payload['domain']?.toString();
    if (domain == null || domain.isEmpty) {
      throw BridgeError.invalidParams('domain is required to get credentials');
    }

    return await secureStorageRepo.getCredentials(
      appId: context.appId,
      domain: domain,
    );
  }
}

class StorageDeleteCredentialsHandler implements NativeActionHandler {
  final MockSecureStorageRepository secureStorageRepo;

  StorageDeleteCredentialsHandler({required this.secureStorageRepo});

  @override
  String get actionName => 'storage.deleteCredentials';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final domain = payload['domain']?.toString();
    if (domain == null || domain.isEmpty) {
      throw BridgeError.invalidParams('domain is required to delete credentials');
    }

    return await secureStorageRepo.deleteCredentials(
      appId: context.appId,
      domain: domain,
    );
  }
}
