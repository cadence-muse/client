# Phase 13: String Extraction & Screen Localization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-25
**Phase:** 13-String Extraction & Screen Localization
**Areas discussed:** Shared string dedup, Test-strings utility shape, Plural-string consolidation, Scope boundary: shared surfaces

---

## Shared string dedup

| Option | Description | Selected |
|--------|-------------|----------|
| Shared common keys | One ARB entry per distinct phrase, referenced from every screen that uses it | ✓ |
| Per-screen keys | Each screen gets its own key even for identical text | |
| You decide | Claude picks based on Flutter ARB conventions | |

**User's choice:** Shared common keys

| Option | Description | Selected |
|--------|-------------|----------|
| commonX prefix | commonRetry, commonCancel, commonDelete, commonRequiresConnection | ✓ |
| No prefix, bare verb | retry, cancel, delete, requiresConnection | |
| You decide | Claude picks a convention consistent with existing keys | |

**User's choice:** commonX prefix

| Option | Description | Selected |
|--------|-------------|----------|
| Merge near-duplicates too | Unify close-but-not-identical wording into one shared key | ✓ |
| Exact-match only | Only byte-identical strings share a key | |
| You decide | Claude judges case-by-case | |

**User's choice:** Merge near-duplicates too

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — split by role | Action-word buttons share commonX keys; dialog body/title text stays per-screen | ✓ |
| No — merge everything shareable | Any repeated string, button or sentence, gets a shared key | |

**User's choice:** Yes — split by role

---

## Test-strings utility shape

| Option | Description | Selected |
|--------|-------------|----------|
| Wrap AppLocalizations directly | Single source of truth is the ARB file itself | ✓ |
| Handwritten constants file | Mirrors English ARB values, no BuildContext needed | |
| You decide | Claude picks based on least invasive to existing tests | |

**User's choice:** Wrap AppLocalizations directly

| Option | Description | Selected |
|--------|-------------|----------|
| Extension on WidgetTester | tester.strings.commonRetry | ✓ |
| Free function taking BuildContext | appStrings(context).commonRetry | |
| You decide | Claude picks the shape requiring fewest changes | |

**User's choice:** Extension on WidgetTester

| Option | Description | Selected |
|--------|-------------|----------|
| All 29 test files, full migration | Every find.text('<English copy>') across all 29 files replaced | |
| Only touched-file copy assertions | Only tests directly touched while localizing each screen migrate | ✓ |

**User's choice:** Only touched-file copy assertions

| Option | Description | Selected |
|--------|-------------|----------|
| Utility covers plurals too | tester.strings.memberCount(n) / trackCount(n) | ✓ |
| Plurals stay direct | Plural assertions call AppLocalizations directly | |

**User's choice:** Utility covers plurals too

---

## Plural-string consolidation

| Option | Description | Selected |
|--------|-------------|----------|
| One shared memberCount() method | Both call sites use one ARB-backed plural method, deletes duplicate helper | ✓ |
| Keep two call sites, share only the ARB entry | Same ARB entry, no code unification | |
| You decide | Claude judges cleanest consolidation | |

**User's choice:** One shared memberCount() method

| Option | Description | Selected |
|--------|-------------|----------|
| Split: role + memberCount() separately | Role label and count as two separate ARB strings | ✓ |
| One combined ARB message | Single ARB entry interpolates role and count together | |

**User's choice:** Split: role + memberCount() separately

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse trackCount() plural method | Same ICU-plural method as visible track-count display | ✓ |
| Simple templated string, no plural logic | Non-plural ARB entry with a placeholder | |
| You decide | Claude picks based on simplicity | |

**User's choice:** Reuse trackCount() plural method

| Option | Description | Selected |
|--------|-------------|----------|
| Consolidate into one shared constant | Move _maxSetlistTracks to one shared location | ✓ |
| Leave the 3 separate constants as-is | Only touch message text, not the constant duplication | |

**User's choice:** Consolidate into one shared constant

---

## Scope boundary: shared surfaces

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in scope | root_scaffold.dart's 5 NavigationDestination labels localized | ✓ |
| No, defer | Leave nav labels untouched this phase | |

**User's choice:** Yes, in scope (NavigationDestination labels)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in scope | offline_no_cache_view.dart localized, covers ~6 screens | ✓ |
| No, defer | Treat as outside "screen" scope | |

**User's choice:** Yes, in scope (offline_no_cache_view.dart)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in scope | offline_banner.dart localized — visible on every tab when offline | ✓ |
| No, defer | Leave untouched this phase | |

**User's choice:** Yes, in scope (offline_banner.dart)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in scope | login_screen.dart localized despite not being named in ROADMAP's criteria | ✓ |
| No, defer to a future phase | Treat as intentionally out of scope | |

**User's choice:** Yes, in scope (login_screen.dart) — rationale: language preference survives logout (Phase 12 D-04), so a Russian-speaking user could land back on an English login screen otherwise.

---

## Claude's Discretion

- Exact ARB key names beyond the `commonX` convention and per-screen naming scheme
- Judgment on which near-duplicate strings are "close enough" to merge without changing meaning
- ICU plural ARB syntax details (placeholder typing, `@key` metadata) — first use of `{count, plural, ...}` in this pipeline, no existing precedent
- Any other `lib/widgets/` shared files not surfaced during discussion that turn out to have hardcoded strings

## Deferred Ideas

None — discussion stayed within phase scope.
