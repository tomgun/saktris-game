# FEATURES
<!-- spec-format: features-v0.3.1 -->

**Purpose**: A human + machine readable registry of features with stable IDs, status, and acceptance criteria.

**For detailed format documentation, see:** `.agentic/spec/FEATURES.reference.md`

---

## Quick Reference

**Status**: `planned` | `in_progress` | `shipped` | `deprecated`

**Feature template** (copy/paste when adding features):

```markdown
## F-####: FeatureName
- Tags: [tag1, tag2]
- Layer: presentation | business-logic | data | infrastructure
- Domain: gameplay | ui | audio | persistence | foundation
- Priority: critical | high | medium | low
- Parent: none
- Dependencies: none
- Complexity: M
- Status: planned
- Acceptance: spec/acceptance/F-####.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Strategy: unit
  - Unit: todo
  - Integration: n/a
  - Acceptance: todo
- Description:
```

---

## Features

## F-0001: GodotProjectSetup
- Tags: [setup, foundation]
- Layer: infrastructure
- Domain: foundation
- Priority: critical
- Parent: none
- Dependencies: none
- Complexity: M
- Status: shipped
- Acceptance: spec/acceptance/F-0001.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-05
- Implementation:
  - State: complete
  - Code: project.godot, src/main.tscn, src/main.gd, src/systems/*.gd
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Set up Godot 4.5 project with folder structure, basic scenes, and test framework (GUT)

## F-0002: ChessBoardDisplay
- Tags: [ui, board]
- Layer: presentation
- Domain: ui
- Priority: critical
- Parent: none
- Dependencies: F-0001
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0002.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-05
- Implementation:
  - State: complete
  - Code: src/ui/board/board_view.gd, src/ui/board/board_view.tscn, src/ui/board/square.gd, src/ui/board/piece_sprite.gd
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Render 8x8 chess board with alternating colors, coordinate labels, and responsive layout. Supports both click-to-move and drag-and-drop piece movement.

## F-0003: PieceMovementRules
- Tags: [gameplay, rules]
- Layer: business-logic
- Domain: gameplay
- Priority: critical
- Parent: none
- Dependencies: F-0002
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0003.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-05
- Implementation:
  - State: complete
  - Code: src/game/piece.gd, src/game/board.gd
- Tests:
  - Strategy: unit
  - Unit: complete
  - Integration: n/a
  - Acceptance: complete
- Description: Implement movement rules for all six chess piece types (King, Queen, Rook, Bishop, Knight, Pawn) including captures

## F-0004: PieceArrivalSystem
- Tags: [gameplay, arrival]
- Layer: business-logic
- Domain: gameplay
- Priority: high
- Parent: none
- Dependencies: F-0003
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0004.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-06
- Implementation:
  - State: complete
  - Code: src/game/piece_arrival.gd, src/game/game_state.gd
- Tests:
  - Strategy: unit
  - Unit: complete
  - Integration: n/a
  - Acceptance: complete
- Description: System for pieces to arrive one-by-one with next piece preview, column selection, and configurable arrival frequency. Placing a piece ends the turn.

## F-0005: GameLoopAndTurns
- Tags: [gameplay, core]
- Layer: business-logic
- Domain: gameplay
- Priority: critical
- Parent: none
- Dependencies: F-0003, F-0004
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0005.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-06
- Implementation:
  - State: complete
  - Code: src/game/game_state.gd
- Tests:
  - Strategy: unit
  - Unit: complete
  - Integration: n/a
  - Acceptance: complete
- Description: Two-player turn system with check detection, checkmate detection, stalemate handling, and game over conditions. Turn flow: place piece OR move (not both).

## F-0006: SaveLoadSystem
- Tags: [save, persistence]
- Layer: data
- Domain: persistence
- Priority: medium
- Parent: none
- Dependencies: F-0005
- Complexity: M
- Status: planned
- Acceptance: spec/acceptance/F-0006.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Strategy: unit
  - Unit: todo
  - Integration: todo
  - Acceptance: todo
- Description: Persist game state to JSON, restore games, autosave functionality

## F-0007: SettingsMenu
- Tags: [ui, settings]
- Layer: presentation
- Domain: ui
- Priority: medium
- Parent: none
- Dependencies: F-0001
- Complexity: M
- Status: planned
- Acceptance: spec/acceptance/F-0007.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: todo
- Description: Configure game options: piece arrival frequency, arrival order mode (fixed/selectable/random), special rules toggle

## F-0008: AIOpponent
- Tags: [ai, gameplay]
- Layer: business-logic
- Domain: ai
- Priority: high
- Parent: none
- Dependencies: F-0005
- Complexity: XL
- Status: shipped
- Acceptance: spec/acceptance/F-0008.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-07
- Implementation:
  - State: complete
  - Code: src/game/ai.gd
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Computer opponent using minimax algorithm with configurable difficulty (Easy/Medium/Hard)

## F-0009: MoveHistoryNavigation
- Tags: [ui, history]
- Layer: presentation
- Domain: ui
- Priority: low
- Parent: none
- Dependencies: F-0005
- Complexity: M
- Status: planned
- Acceptance: spec/acceptance/F-0009.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Strategy: unit
  - Unit: todo
  - Integration: n/a
  - Acceptance: todo
- Description: View move history, navigate back/forward through moves (like chess.com analysis)

## F-0010: ArrowDrawing
- Tags: [ui, planning]
- Layer: presentation
- Domain: ui
- Priority: medium
- Parent: none
- Dependencies: F-0002
- Complexity: M
- Status: shipped
- Acceptance: spec/acceptance/F-0010.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-07
- Implementation:
  - State: complete
  - Code: src/ui/board/board_view.gd, src/ui/board/board_view.tscn, export_templates/web_shell.html
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Draw arrows on board for planning moves (right-click drag). Arrows validate against piece movement patterns but ignore blockers. Works on any piece regardless of turn. Knight arrows show L-shaped paths matching their movement pattern. Custom HTML shell prevents browser context menu in web export.

## F-0011: SpecialChessRules
- Tags: [gameplay, rules]
- Layer: business-logic
- Domain: gameplay
- Priority: high
- Parent: F-0003
- Dependencies: F-0003
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0011.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-06
- Implementation:
  - State: complete
  - Code: src/game/board.gd, src/game/game_state.gd, src/ui/board/board_view.gd
- Tests:
  - Strategy: unit
  - Unit: complete
  - Integration: n/a
  - Acceptance: complete
- Description: Implement castling, en passant, pawn promotion

## F-0012: PhysicsBumpMode
- Tags: [visual, physics]
- Layer: presentation
- Domain: effects
- Priority: medium
- Parent: none
- Dependencies: F-0003
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0012.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-07
- Implementation:
  - State: complete
  - Code: src/ui/board/piece_sprite.gd, src/game/board.gd, src/ui/board/board_view.gd, src/systems/settings.gd
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Optional visual mode where captured pieces are bumped off with physics animation. Includes collision sparks (particle effects), collision sounds, and motion trails for long-distance moves by rooks/bishops/queens.

## F-0013: TripletClearRule
- Tags: [gameplay, rules]
- Layer: business-logic
- Domain: gameplay
- Priority: high
- Parent: none
- Dependencies: F-0003, F-0012
- Complexity: L
- Status: shipped
- Acceptance: spec/acceptance/F-0013.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-08
- Implementation:
  - State: complete
  - Code: src/game/board.gd, src/game/game_state.gd, src/ui/board/board_view.gd, src/systems/settings.gd
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Optional Tetris-inspired rule: when 3 pieces of the same type form a line (horizontally or vertically), all three are cleared. Direction is determined by the last-moved piece. Cleared pieces exit toward the first piece in that direction, which gets "bumped" off. If the bumped piece is an opponent's king, the clearing player wins. Only triggers after moves (not placements). Includes collision sound for bumps and special triplet clear sound.

## F-0014: BishopPlacementRule
- Tags: [gameplay, rules]
- Layer: business-logic
- Domain: gameplay
- Priority: medium
- Parent: F-0004
- Dependencies: F-0004
- Complexity: S
- Status: shipped
- Acceptance: spec/acceptance/F-0014.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-06
- Implementation:
  - State: complete
  - Code: src/game/board.gd
- Tests:
  - Strategy: unit
  - Unit: complete (tests/unit/test_board.gd)
  - Integration: n/a
  - Acceptance: complete
- Description: Bishops cannot be placed on the same color square as an existing bishop of the same player. Ensures opposite-colored bishop pair like standard chess.

## F-0015: SoundFXAndThemes
- Tags: [audio, themes]
- Layer: presentation
- Domain: audio
- Priority: medium
- Parent: none
- Dependencies: F-0001
- Complexity: M
- Status: shipped
- Acceptance: spec/acceptance/F-0015.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-08
- Implementation:
  - State: complete
  - Code: src/systems/audio_manager.gd, src/systems/audio_theme.gd, src/systems/theme_manager.gd, assets/audio/themes/classic/
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Sound effects system with support for switchable audiovisual themes. Includes move sounds, capture sounds, check/checkmate alerts, collision sounds, triplet clear sounds, and UI feedback. Theme system allows different sound sets that can later be paired with visual styles.

## F-0016: TimerMode
- Tags: [gameplay, clock]
- Layer: business-logic
- Domain: gameplay
- Priority: medium
- Parent: none
- Dependencies: F-0005
- Complexity: M
- Status: shipped
- Acceptance: spec/acceptance/F-0016.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-08
- Implementation:
  - State: complete
  - Code: src/game/chess_clock.gd, src/game/game_state.gd
- Tests:
  - Strategy: unit
  - Unit: complete
  - Integration: n/a
  - Acceptance: complete
- Description: Chess clock with standard time controls (bullet, blitz, rapid, classical). Per-player countdown with time-out detection.

## F-0017: DrawRules
- Tags: [gameplay, rules]
- Layer: business-logic
- Domain: gameplay
- Priority: medium
- Parent: F-0005
- Dependencies: F-0005
- Complexity: M
- Status: shipped
- Acceptance: spec/acceptance/F-0017.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-08
- Implementation:
  - State: complete
  - Code: src/game/draw_detector.gd, src/game/position_hash.gd, src/game/game_state.gd
- Tests:
  - Strategy: unit
  - Unit: complete
  - Integration: n/a
  - Acceptance: complete
- Description: Draw detection for 50-move rule, threefold repetition, and insufficient material (K vs K, K+B vs K, K+N vs K).

## F-0018: MultiplePieceSets
- Tags: [ui, visuals]
- Layer: presentation
- Domain: ui
- Priority: low
- Parent: F-0002
- Dependencies: F-0002
- Complexity: M
- Status: shipped
- Acceptance: spec/acceptance/F-0018.md
- Verification:
  - Accepted: yes
  - Accepted at: 2026-01-09
- Implementation:
  - State: complete
  - Code: src/ui/board/piece_sprite.gd, src/systems/settings.gd, assets/sprites/pieces/
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: complete
- Description: Multiple piece set options including standard flat (CBurnett) and spatial 3D-style pieces with depth and shadows.

## F-0019: MobileView
- Tags: [ui, mobile, responsive]
- Layer: presentation
- Domain: ui
- Priority: medium
- Parent: F-0002
- Dependencies: F-0002
- Complexity: L
- Status: in_progress
- Acceptance: spec/acceptance/F-0019.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: partial
  - Code:
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: todo
- Description: Responsive mobile layout with touch input support. Screen width < 800px triggers vertical layout. Includes tap-to-move, drag-to-move, and long-press for arrow drawing.

## F-0020: GameRulesScreen
- Tags: [ui, help]
- Layer: presentation
- Domain: ui
- Priority: medium
- Parent: none
- Dependencies: none
- Complexity: S
- Status: planned
- Acceptance: spec/acceptance/F-0020.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Strategy: manual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: todo
- Description: In-game rules screen accessible from main menu. Shows Saktris rules including piece arrival system, placement rules, and victory conditions.

## F-0021: OnlineMultiplayer
- Tags: [multiplayer, networking]
- Layer: infrastructure
- Domain: gameplay
- Priority: medium
- Parent: none
- Dependencies: F-0005
- Complexity: L
- Status: planned
- Acceptance: spec/acceptance/F-0021.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Strategy: integration
  - Unit: n/a
  - Integration: todo
  - Acceptance: todo
- Description: Browser-to-browser online multiplayer using WebRTC or WebSocket. Players can create/join game rooms and play against each other in real-time. Includes game state synchronization, move validation, and disconnect handling.
