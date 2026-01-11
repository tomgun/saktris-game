# NFR (Non-Functional Requirements)

<!-- format: nfr-v0.1.0 -->

Purpose: capture cross-cutting constraints that apply across many features.

---

## NFR-0001: Frame Rate
- Category: performance
- Statement: Maintain 60 FPS on mid-range devices (2020+ phones)
- Applies to: all rendering, animations, physics
- How to measure: Godot profiler, frame time < 16.6ms
- Where enforced:
  - Tests: manual performance testing
  - CI: none yet
- Current status: met
- Notes: Physics bump mode tested at 60 FPS

## NFR-0002: Memory Usage
- Category: performance
- Statement: Peak memory usage < 200MB on mobile
- Applies to: all (mobile builds)
- How to measure: Device memory profiler
- Where enforced:
  - Tests: manual on device
  - CI: none yet
- Current status: unknown
- Notes: Not yet tested on mobile

## NFR-0003: App Size
- Category: performance
- Statement: APK < 50MB, HTML5 < 30MB
- Applies to: release builds
- How to measure: File size after export
- Where enforced:
  - Tests: export and check
  - CI: none yet
- Current status: met
- Notes: Current web build ~15MB

## NFR-0004: Input Responsiveness
- Category: usability
- Statement: Input-to-visual feedback < 100ms
- Applies to: all user interactions
- How to measure: Visual inspection
- Where enforced:
  - Tests: manual testing
  - CI: none
- Current status: met
- Notes: Drag-and-drop feels responsive

## NFR-0005: Cross-Platform
- Category: compatibility
- Statement: Works on Web, iOS, Android, Desktop
- Applies to: all features
- How to measure: Test on each platform
- Where enforced:
  - Tests: manual per-platform testing
  - CI: GitHub Actions for web
- Current status: partial
- Notes: Web tested, mobile not yet

## NFR-0006: AI Response Time
- Category: performance
- Statement: AI move calculation < 2 seconds on HARD difficulty
- Applies to: F-0008 AI opponent
- How to measure: Time from turn start to move selection
- Where enforced:
  - Tests: unit tests with timing assertions
  - CI: GUT test suite
- Current status: met
- Notes: Optimized with make_move/undo_move pattern (no board copying) + background thread to keep UI responsive during calculation.
