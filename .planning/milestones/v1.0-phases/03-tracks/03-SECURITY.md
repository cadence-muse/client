---
phase: 03
slug: tracks
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-16
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Client -> Cadence backend API | `listBandTracks`/`getBandTrack`/`createBandTrack`/`updateBandTrack`/`deleteBandTrack`/global `GET /api/track/list` cross the network; responses are untrusted until parsed/typed by the client | Track fields (title/artist/duration/tempo/key/notes), band-scoped track lists |
| User input -> CreateTrackScreen / EditTrackScreen form | Title/artist/duration/tempo/key/notes are untrusted free text entered on-device before being sent to the server | Free-text track metadata |
| App -> device-local Hive tracksBox | Cached per-band and global track lists/details persist in the app's private sandboxed storage | Track metadata (no auth/PII data) |
| Mobile client -> Public API (`PUT` updateBandTrack, CR-02 fix) | Same boundary as create/update above — 03-04 changes what the client sends (unconditional body with typed-required title/artist), not the boundary itself | Track update payload |
| Local Riverpod/Hive cache (in-process, on-device) | Not a network trust boundary; touched only by cache-invalidation calls | In-process state only |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-03-01 | Tampering | `POST /api/band/{bandId}/track` (createBandTrack) | low | accept | Server is the authoritative validator of all submitted fields; client-side validators are UX only | closed |
| T-03-02 | Information Disclosure | tracksBox Hive cache (device-local) | low | accept | OS-sandboxed private directory, same accepted pattern as Phase 1/2 boxes; no auth/PII data | closed |
| T-03-03 | Elevation of Privilege | Track view/create access (no owner-only path) | low | accept | Server enforces band-membership scoping; requirements carry no owner qualifier | closed |
| T-03-04 | Denial of Service | Malformed JSON response from track list/detail endpoints | low | accept | Existing `ApiClient.send()` decode/status handling unchanged, same pattern as Phase 1/2 | closed |
| T-03-05 | Tampering | Man-in-the-middle on track API calls | medium | accept | HTTPS enforced via existing `ApiClient`/`AppConfig.apiBaseUrl`; cert pinning explicitly deferred (out of ASVS L1 scope) | closed |
| T-03-06 | Tampering | `PUT /api/band/{bandId}/track/{trackId}` (updateBandTrack) | low | accept | Server validates and is authoritative; client merges submitted values into cache, not a trusted response body | closed |
| T-03-07 | Repudiation | `DELETE /api/band/{bandId}/track/{trackId}` (deleteBandTrack) | low | accept | Immediate/irreversible delete matches accepted pattern from Phase 2 (Leave Band / Remove Member); no audit trail required for v1 | closed |
| T-03-08 | Elevation of Privilege | Edit/Delete track access (no owner-only path) | low | accept | Server-side band-membership scoping only, confirmed by RESEARCH.md; client adds no ownership gate by design | closed |
| T-03-09 | Information Disclosure | `GET /api/track/list` response scope | low | accept | Server scopes `items` to the requesting user's own bands; client adds no redundant filtering | closed |
| T-03-10 | Tampering | `bandId` query parameter (client-supplied filter) | low | accept | Filter only narrows an already user-scoped response; server membership scoping governs the full item set | closed |
| T-03-11 | Denial of Service | `ApiClient.queryParameters` construction (`Uri.replace`) | low | accept | `Uri.replace(queryParameters: null)` is a Dart SDK no-op; additive change covered by existing call-site tests | closed |
| T-03-04-01 | Tampering | `PublicApi.updateBandTrack` request body (CR-02 fix) | low | mitigate | `title`/`artist` typed `required String` (non-nullable) in the Dart method signature — verified present in `lib/api/public_api.dart:167-176`; compiler prevents sending `null` for those two fields | closed |
| T-03-04-02 | Tampering | Duration/Tempo `TextFormField` validators (WR-02 fix) | low | accept | Client-side numeric validation is UX only; server remains authoritative validator, unchanged from 03-01's threat model | closed |
| T-03-04-03 | Denial of Service (client-side) | `RootScaffold` `ConsumerWidget` + `selectedTabIndexProvider` (WR-01 fix) | low | accept | Purely local, in-memory `AutoDispose` UI state; no persistence, no network I/O, no external attack surface | closed |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-01, T-03-02, T-03-03, T-03-04, T-03-05, T-03-06, T-03-07, T-03-08, T-03-09, T-03-10, T-03-11, T-03-04-02, T-03-04-03 | All rated low (one medium, MITM, covered by existing HTTPS infra); dispositions authored at plan time in 03-01/03-02/03-03/03-04 PLAN.md threat models, consistent with accepted-risk patterns already established in Phase 1/2 | GSD secure-phase (plan-time disposition) | 2026-08-16 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-16 | 14 | 14 | 0 | gsd-secure-phase (L1 short-circuit — register authored at plan time, threats_open: 0, ASVS L1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-16
