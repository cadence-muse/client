import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

/// Device-radio-state connectivity, as reported by `connectivity_plus` (D-01
/// — radio/interface state, not an active reachability ping; a wifi network
/// with no real internet still reads as [online]).
enum ConnectivityStatus { online, offline }

/// Maps a `connectivity_plus` result list to [ConnectivityStatus]. Online
/// requires at least one entry that isn't [ConnectivityResult.none].
ConnectivityStatus _mapResults(List<ConnectivityResult> results) {
  final hasConnection = results.any(
    (result) => result != ConnectivityResult.none,
  );
  return hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline;
}

/// D-02: single global connectivity signal, seeded via a one-shot
/// `checkConnectivity()` before subscribing to `onConnectivityChanged` — so
/// there is no null/loading gap between app start and the first stream event
/// (UI-SPEC E3/E4). D-03: every event is passed straight through, no
/// debounce.
@riverpod
Stream<ConnectivityStatus> connectivity(ConnectivityRef ref) async* {
  final connectivity = Connectivity();
  yield _mapResults(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_mapResults);
}

/// The single value every other file in this phase watches — no other file
/// should call `.when()` on [connectivityProvider] directly. Resolves to
/// `true` only for `AsyncData(ConnectivityStatus.online)`; both
/// `AsyncLoading` and `AsyncError` (including a `connectivity_plus`
/// platform-channel failure) resolve to `false` — fail-safe offline default.
@riverpod
bool isOnline(IsOnlineRef ref) {
  final status = ref.watch(connectivityProvider);
  return status.asData?.value == ConnectivityStatus.online;
}
