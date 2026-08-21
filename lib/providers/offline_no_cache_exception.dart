/// Thrown by an online-first provider's `build()` when the device is
/// offline and there is no cached data for the requested resource (D-06).
///
/// This is the single shared exception type every online-first provider
/// introduced in Phase 7 throws for this case (mirroring
/// `BandsListData`/`BandDetailData`'s shape) — every screen's `error:`
/// branch checks for it with `is OfflineNoCacheException` to render
/// [OfflineNoCacheView] instead of the generic "Couldn't load" error state.
class OfflineNoCacheException implements Exception {
  const OfflineNoCacheException();

  @override
  String toString() =>
      'OfflineNoCacheException: no cached data available while offline';
}
