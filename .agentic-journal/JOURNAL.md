# JOURNAL

<!-- format: journal-v0.1.0 -->

**Purpose**: Capture session-by-session progress so both humans and agents can resume work effortlessly.

📖 **For format options, examples, and guidelines, see:** `.agentic/spec/JOURNAL.reference.md`

---

## Session Log (most recent first)

<!-- Agents: Append new session entries here after meaningful work -->
<!-- Format: ### Session: YYYY-MM-DD HH:MM -->

### Session: 2026-02-25 23:28 - Online Multiplayer Fix

**Why**: Critical bug prevented guest from connecting

**Accomplished**:
- Fixed WebRTC data_channel_received bug, added signaling server health endpoint, updated URL to Render, deployed signaling server

**Next steps**:
- End-to-end multiplayer testing

**Blockers**: None


### Session: 2026-02-25 23:31 - Housekeeping

**Why**: Cleanup untracked files

**Accomplished**:
- Added gitignore for node_modules, committed package-lock and multiplayer plan

**Next steps**:
- End-to-end multiplayer testing

**Blockers**: None


### Session: 2026-02-25 23:38 - Room Code UX

**Why**: UX improvement for sharing room codes

**Accomplished**:
- Made room code copy-pasteable with selectable LineEdit and Copy button

**Next steps**:
- End-to-end multiplayer testing

**Blockers**: None


### Session: 2026-02-26 10:36 - Multiplayer UX

**Why**: UX polish for join flow and Render cold starts

**Accomplished**:
- Added Join button to room code input, added slow-connect server wakeup indicator

**Next steps**:
- E2E multiplayer testing

**Blockers**: None

# JOURNAL

<!-- format: journal-v0.1.0 -->

**Purpose**: Capture session-by-session progress so both humans and agents can resume work effortlessly.

📖 **For format options, examples, and guidelines, see:** `.agentic/spec/JOURNAL.reference.md`

---

## Session Log (most recent first)

### Session: 2026-01-11

**Focus**: Bug fix - King capture not ending game

**Completed**:
- Fixed game not properly ending when king is captured
- Game now correctly detects king capture as game over

**Commit**: `69c9813`

---

### Session: 2026-01-10

**Focus**: Web build fixes, AI threading

**Completed**:
- Fixed web build: added import step for proper asset loading
- Implemented threaded AI calculation (background thread keeps UI/animations smooth)
- Added audio files and theme system to git tracking

**Commits**: `0c8d6f8`, `53ba4d2`

---

### Session: 2026-01-09

**Focus**: AI optimization, Multiple piece sets (F-0018)

**Completed**:
- Optimized AI with move/undo pattern for 10-20x speedup
  - Instead of cloning board state, use make_move/undo_move
  - Dramatically faster minimax search
- Implemented multiple piece sets (F-0018):
  - Standard flat pieces (CBurnett)
  - Spatial 3D-style pieces with depth/shadows
  - Toggle in settings

**Commits**: `a15b90a`, `a656872`

---

### Session: 2026-01-08

**Focus**: Timer mode (F-0016), Draw rules (F-0017)

**Completed**:
- Implemented timer mode / chess clock (F-0016):
  - Standard time controls (bullet, blitz, rapid, classical)
  - Per-player countdown
  - Time-out detection
- Implemented draw rules (F-0017):
  - 50-move rule (no pawn moves or captures)
  - Threefold repetition detection
  - Insufficient material detection (K vs K, K+B vs K, K+N vs K)
- Framework alignment + F-0014 tests + GDScript fixes

**Commits**: `aed8ef9`, `fcc65f3`, `5bd65ea`

---

### Session: 2026-01-07 (continued)

**Focus**: Physics Bump Mode (F-0012)

**Completed**:
- Implemented physics bump animation when pieces are captured:
  - Captured pieces fly off board with real physics simulation (gravity, velocity)
  - Direction based on attacker's approach angle
  - Rotation and fade-out as piece falls off screen
  - **Collision detection**: flying pieces bump into other pieces on the way out
  - **Elastic return**: bumped pieces wobble and smoothly return to their positions
- Updated `piece_captured` signal to include attacker's from position
- Toggle via `Settings.physics_bump_enabled` (default: on)
- All 62 unit tests passing

**Files modified**:
- `src/ui/board/piece_sprite.gd` - Physics state variables, `start_bump()`, `nudge()`, `physics_update()`, collision helpers
- `src/game/board.gd` - Extended `piece_captured` signal with attacker position
- `src/ui/board/board_view.gd` - Physics loop in `_process()`, collision detection, `bumping_pieces` tracking
- `src/game/game_state.gd` - Updated signal handler signature
- `src/systems/settings.gd` - Enabled physics bump by default
- `src/game/ai.gd` - Fixed string formatting error in debug print

**Additional fixes**:
- Fixed physics direction calculation to use screen coordinates instead of board coordinates
- Added `is_moving` flag to prevent attacking piece from being nudged during animation
- Added `can_place_piece()` and `must_place_piece()` helpers to handle blocked back row
- Game no longer deadlocks if back row is full - player skips placement and just moves
- Return animation slowed by 20% (0.3s → 0.36s)

---

### Session: 2026-01-07

**Focus**: Game flow fix with TDD - place AND move in same turn

**Problem**: Game was switching turns after placing a piece, but correct Saktris flow is:
- Place a piece (if you have one to place)
- Then make a move with any piece on the board
- Turn ends after the move

**Completed**:
- Fixed `try_place_piece()` to NOT switch turns - player places then moves
- Fixed `request_ai_move()` to handle place+move in same AI turn
- Fixed stalemate detection for Saktris rules:
  - Not stalemate if opponent has pieces remaining in queue
  - This prevents false stalemate when opponent hasn't placed yet
- Created comprehensive TDD test suite for piece arrival rules:
  - `test_piece_arrival_rules.gd` - 11 tests covering all arrival scenarios
- Updated all game flow tests for new turn structure
- All 62 unit tests passing

**Key changes**:
- `game_state.gd`:
  - `try_place_piece()` no longer calls `_switch_turn()`
  - `request_ai_move()` places piece first (if needed), then makes a move
  - `_update_game_status()` checks for remaining pieces before declaring stalemate/checkmate
- `test_piece_arrival_rules.gd`: New TDD tests defining arrival behavior:
  - First piece arrives immediately
  - Subsequent pieces arrive every N moves (arrival_frequency)
  - Moves counted per-player, not globally
  - Queue contains all 16 pieces
- `test_game_flow.gd`: All tests updated for place+move turn structure

**Piece Arrival Rules** (now tested):
1. First piece arrives immediately at game start
2. After placing first piece, next piece arrives after N moves (frequency)
3. Each player's moves tracked separately
4. Turn = place (if available) + move

---

### Session: 2026-01-06 (continued #3)

**Focus**: AI opponent (F-0008)

**Completed**:
- Implemented chess AI with minimax algorithm:
  - `src/game/ai.gd` - ChessAI class with configurable difficulty
  - Alpha-beta pruning for performance
  - Material-based position evaluation
  - Position bonuses (center control, pawn advancement)
  - Three difficulty levels: EASY (depth 1), MEDIUM (depth 3), HARD (depth 4)
- AI handles both piece placement and regular moves
- Integrated AI into game flow:
  - `game_state.gd` - AI turn detection, move requests
  - `board_view.gd` - Triggers AI moves with visual delay
  - `settings.gd` - Game mode, AI difficulty, AI side options
- Default: VS_AI mode, AI plays Black, Medium difficulty
- All 39 unit tests passing

**Files created**:
- `src/game/ai.gd` - Complete AI implementation

**Files modified**:
- `src/game/game_state.gd` - AI integration, signals
- `src/ui/board/board_view.gd` - AI turn handling
- `src/systems/settings.gd` - AI settings

**Next**:
- Main menu

---

### Session: 2026-01-06 (continued #2)

**Focus**: Special chess moves (F-0011)

**Completed**:
- Implemented castling:
  - Kingside (O-O) and queenside (O-O-O) for both colors
  - Validates: king/rook not moved, path clear, not in/through/into check
  - Rook automatically moves when king castles
  - 7 new tests for castling
- Implemented en passant:
  - Tracks en_passant_target when pawn moves 2 squares
  - Target cleared after next move
  - Pawn captured from adjacent square (not target square)
  - 4 new tests for en passant
- All 39 unit tests passing

**Files modified**:
- `src/game/board.gd` - Added castling logic, en passant tracking, serialization
- `tests/unit/test_board.gd` - Added 11 tests for special moves

**Next**:
- AI opponent (F-0008)
- Main menu

---

### Session: 2026-01-06 (continued)

**Focus**: Pawn promotion implementation

**Completed**:
- Implemented full pawn promotion system:
  - Detection when pawn reaches promotion row (row 7 for White, row 0 for Black)
  - `promotion_required` signal in board.gd
  - `promote_pawn()` function to replace pawn with promoted piece
  - `promotion_needed` signal in game_state.gd
  - Pending promotion state management (blocks moves until promotion complete)
  - `complete_promotion()` function for UI callback
  - Promotion dialog UI with piece selection buttons (Q/R/B/N)
  - Sprite replacement on promotion
- Added 3 new unit tests for promotion (28 tests total, all passing)

**Files modified**:
- `src/game/board.gd` - Added promotion detection, promote_pawn(), signal
- `src/game/game_state.gd` - Added promotion flow, pending state, signal
- `src/ui/board/board_view.gd` - Added promotion dialog handling
- `src/ui/board/board_view.tscn` - Added PromotionDialog panel
- `tests/unit/test_board.gd` - Added promotion tests

**Next**:
- Castling / en passant (F-0011)
- AI opponent (F-0008)
- Main menu

---

### Session: 2026-01-06

**Focus**: UI implementation and bug fixes

**Completed**:
- Fixed GDScript enum type errors (Piece.Side vs int parameter types)
- All 25 unit tests passing
- Downloaded CBurnett chess piece sprites (CC-BY-SA 3.0)
- Implemented full board UI (F-0002):
  - `src/ui/board/square.gd/tscn` - Clickable board squares
  - `src/ui/board/piece_sprite.gd/tscn` - Piece visuals with animation
  - `src/ui/board/board_view.gd/tscn` - Main board view with grid, selection, highlights
- Click-to-select, click-to-move interaction
- Legal move highlighting (dots for moves, overlay for captures)
- Last move highlighting
- Piece arrival panel with current piece display
- Piece queue preview (configurable count via Settings.piece_preview_count)
- Turn indicator and game status display

**Bug fixes**:
- Fixed turn not switching after piece placement
- Fixed piece order (was random, now FIXED mode by default)
- Changed default order: 8 pawns → 2 knights → 2 bishops → king → 2 rooks → queen
- Fixed pawn movement direction (White moves +Y, Black moves -Y)
- Fixed settings not being passed to game (now uses Settings.get_game_settings())

**Files created/modified**:
- `assets/sprites/pieces/*.svg` - 12 piece sprites
- `src/ui/board/*` - All board UI components
- `src/main.gd` - Wired up board view
- `src/game/board.gd` - Fixed pawn direction
- `src/game/game_state.gd` - Fixed turn switching after placement
- `src/game/piece_arrival.gd` - New piece order, get_upcoming_pieces()
- `src/systems/settings.gd` - Added piece_preview_count, changed default mode to FIXED

**Current state**:
- Game is playable! Place pieces, move them, captures work
- Arrival system working (pieces arrive every 2 moves after initial placement)

**Next**:
- Pawn promotion
- Castling / en passant (F-0011)
- AI opponent (F-0008)
- Main menu

---

### Session: 2026-01-05 20:15

**Focus**: Project initialization and Godot setup

**Completed**:
- Initialized agentic framework with Core+PM profile
- Filled in all documentation: STACK.md, PRODUCT.md, CONTEXT_PACK.md, STATUS.md
- Created spec documents: PRD.md, TECH_SPEC.md, FEATURES.md (13 features planned)
- Wrote game rules: docs/CHESS_RULES.md, docs/SAKTRIS_RULES.md
- Created Godot 4.5 project structure
- Implemented core game logic:
  - `src/game/piece.gd` - Piece class with types, colors, serialization
  - `src/game/board.gd` - Board state, all piece movement rules, check detection
  - `src/game/game_state.gd` - Game loop, turns, win conditions
  - `src/game/piece_arrival.gd` - Saktris arrival system (3 modes)
- Created system autoloads: GameManager, Settings
- Set up unit tests: test_piece.gd, test_board.gd
- Created .gitignore, LICENSE (proprietary), assets/ATTRIBUTION.md

**Decisions made**:
- Engine: Godot 4.5.1 (MIT licensed, no royalties)
- Language: GDScript
- Test framework: GUT (needs manual install - see HN-0001)
- License: Proprietary

**In progress** (F-0001, F-0003, F-0004, F-0005):
- Core game logic implemented but needs UI
- Tests written but GUT not yet installed

**Blockers** (see HUMAN_NEEDED.md):
- HN-0001: Install GUT plugin from Asset Library
- HN-0002: Decide victory conditions
- HN-0003: Decide blocked placement behavior

**Next session**:
- Install GUT and verify tests pass
- Create board visual (F-0002)
- Create piece sprites or use placeholder graphics

### Session: 2026-01-11 21:14 - F-0019 Mobile View implementation

**Accomplished**:
- - Implemented mobile layout switching (< 800px width)\n- Added touch input support (tap, drag, long-press for arrows)\n- Created mobile UI overlay (top status bar, bottom controls)\n- Updated viewport meta tag for proper mobile scaling\n- Added mobile-specific queue display and New Game button

**Next steps**:
- - Test on actual mobile device\n- Fix any UX issues discovered in testing\n- Mark feature as complete after acceptance

**Blockers**: Need to smoke test on real mobile device


### Session: 2026-02-26 10:53 - Framework Upgrade

**Why**: Keep framework current

**Accomplished**:
- Upgraded agentic framework from 0.33.0 to 0.33.1

**Next steps**:
- E2E multiplayer testing

**Blockers**: None


### Session: 2026-02-26 11:04 - Framework

**Why**: Complete framework upgrade

**Accomplished**:
- Committed upgrade.sh from 0.33.1 upgrade

**Next steps**:
- Multiplayer testing

**Blockers**: None


### Session: 2026-02-26 11:05 - Settings

**Why**: Cleanup temp setting

**Accomplished**:
- Reset max_code_file_length back to 500

**Next steps**:
- Multiplayer testing

**Blockers**: None


### Session: 2026-02-26 11:12 - Framework 0.33.2

**Why**: Patch fixes false positive we hit with upgrade.sh

**Accomplished**:
- Upgraded to 0.33.2 - fixes pre-commit file length check for framework files

**Next steps**:
- Multiplayer testing

**Blockers**: None


### Session: 2026-02-26 11:52 - F-0012 Player Name System

**Why**: New feature for online multiplayer identity

**Accomplished**:
- Implemented player name persistence in Settings, settings menu UI, and multiplayer name prompt

**Next steps**:
- Manual testing in Godot

**Blockers**: None


### Session: 2026-02-26 22:49 - Multi-feature commit

**Why**: Committing accumulated robustness improvements

**Accomplished**:
- AI safety guards (abort/timeout/fallback), iteration guards in board/game_state, tween lifecycle tracking, network cold-start retry with auto-reconnect, STACK.md settings reorganization

**Next steps**:
- Investigate game stall bug (AI turn not completing)

**Blockers**: None


### Session: 2026-02-26 23:06 - AI stall fix

**Why**: Bug fix for game-stalling AI issue

**Accomplished**:
- Fixed AI stalling when back row full - placement returns column:-1, AI now falls back to regular move per AC8 rules

**Next steps**:
- Test the fix in-game

**Blockers**: None


### Session: 2026-02-26 23:48 - Online UI fix

**Why**: Bug fix: opponent placement UI visible to local player

**Accomplished**:
- Hide opponent's arrival piece/highlights/queue during their turn in online mode

**Next steps**:
- Test in multiplayer game

**Blockers**: None


### Session: 2026-02-26 23:52 - Side selector UX

**Why**: UX improvement: side choice irrelevant for joining player

**Accomplished**:
- Moved side selector behind Create Game click - only host picks side

**Next steps**:
- None

**Blockers**: None


### Session: 2026-02-26 23:58 - Game style setting

**Why**: Make action mode available for all game types

**Accomplished**:
- Added Classic/Action game style selector in Settings, applies to all game types

**Next steps**:
- Test action mode across all game types

**Blockers**: None

