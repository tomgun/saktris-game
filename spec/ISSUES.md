# Issues & Bugs

<!-- format: issues-v0.1.0 -->

**Purpose**: Track bugs, issues, and technical debt found during development.

---

## Summary

| Status | Count |
|--------|-------|
| Open | 2 |
| In Progress | 0 |
| Fixed | 0 |
| Won't Fix | 0 |
| **Total** | 2 |

---

## Open Issues

## I-0001: Mobile portrait board too small

**Status**: open
**Priority**: high
**Severity**: major
**Found**: 2026-01-14
**Fixed**:

**Description**:
On iPhone 14 Pro Safari in portrait orientation, the chess board is too small. It should be maximized to fill available width, with other UI elements (status, controls) fitting above/below.

**Steps to Reproduce**:
1. Open https://tomgun.github.io/saktris-game/ on iPhone 14 Pro
2. Hold phone in portrait (vertical) orientation
3. Observe board is smaller than it could be

**Environment**:
- Device: iPhone 14 Pro
- OS: iOS
- Browser: Safari

**Related**:
- Feature: F-0019 (Mobile View)

---

## I-0002: Pieces break after rotating to landscape

**Status**: open
**Priority**: critical
**Severity**: blocker
**Found**: 2026-01-14
**Fixed**:

**Description**:
After rotating phone from portrait to landscape, pieces appear in wrong positions (semi-random) and cannot be moved. Game becomes unplayable.

**Steps to Reproduce**:
1. Open https://tomgun.github.io/saktris-game/ on iPhone 14 Pro
2. Start a game in portrait orientation
3. Place some pieces / make moves
4. Rotate phone to landscape (horizontal)
5. Observe pieces are misplaced and unmovable

**Environment**:
- Device: iPhone 14 Pro
- OS: iOS
- Browser: Safari

**Related**:
- Feature: F-0019 (Mobile View)

---

## In Progress

<!-- Issues being actively worked on -->

---

## Recently Fixed

<!-- Last 5-10 fixed issues for reference -->

---

## Won't Fix / Duplicates

<!-- Issues closed without fix, with explanation -->
