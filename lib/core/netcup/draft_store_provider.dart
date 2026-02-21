import 'netcup_bootstrap.dart';
import 'profile_draft_store.dart';

class DraftStoreProvider {
  DraftStoreProvider._();

  static ProfileDraftStore? _store;

  static ProfileDraftStore get store {
    return _store ??= NetcupBootstrap.createDraftStore();
  }

  static void reset() {
    _store = null;
  }
}
