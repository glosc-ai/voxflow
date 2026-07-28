import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/privacy_notice_repository.dart';
import 'settings_provider.dart';

final privacyNoticeRepositoryProvider = Provider<PrivacyNoticeRepository>(
  (ref) => PrivacyNoticeRepository(ref.watch(sharedPreferencesProvider)),
);

final privacyNoticeProvider =
    StateNotifierProvider<PrivacyNoticeNotifier, bool>((ref) {
  return PrivacyNoticeNotifier(ref.watch(privacyNoticeRepositoryProvider));
});

class PrivacyNoticeNotifier extends StateNotifier<bool> {
  PrivacyNoticeNotifier(this._repository) : super(_repository.isAcknowledged());

  final PrivacyNoticeRepository _repository;

  Future<void> acknowledge() async {
    if (state) {
      return;
    }
    await _repository.acknowledge();
    state = true;
  }
}
