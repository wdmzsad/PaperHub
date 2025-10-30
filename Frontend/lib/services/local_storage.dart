class LocalStorage {
  LocalStorage._private();
  static final LocalStorage instance = LocalStorage._private();
  final Map<String, String> _map = {};

  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  Future<void> delete(String key) async {
    _map.remove(key);
  }

  String? read(String key) {
    return _map[key];
  }
}
