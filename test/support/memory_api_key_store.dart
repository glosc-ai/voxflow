import 'package:voxflow/features/settings/services/api_key_store.dart';

class MemoryApiKeyStore implements ApiKeyStore {
  MemoryApiKeyStore({String? initialValue}) : value = initialValue;

  String? value;
  Object? readError;
  Object? writeError;
  Object? deleteError;
  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<String?> read() async {
    readCount += 1;
    final error = readError;
    if (error != null) {
      throw error;
    }
    return value;
  }

  @override
  Future<void> write(String nextValue) async {
    writeCount += 1;
    final error = writeError;
    if (error != null) {
      throw error;
    }
    value = nextValue;
  }

  @override
  Future<void> delete() async {
    deleteCount += 1;
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    value = null;
  }
}
