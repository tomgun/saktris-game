# FEATURES
<!-- spec-format: features-v0.3.1 -->

**Purpose**: A human + machine readable registry of features with stable IDs, status, and acceptance criteria.

---

## Quick Reference

**Status**: `planned` | `in_progress` | `shipped` | `deprecated`

---

## Features

## F-0001: GodotProjectSetup
- Parent: none
- Dependencies: none
- Status: in_progress
- Acceptance: spec/acceptance/F-0001.md
- Implementation:
  - State: partial
  - Files: project.godot, src/main.tscn, src/main.gd, src/systems/*.gd
- Tests:
  - Unit: N/A
- Description: Set up Godot 4.5 project with folder structure, basic scenes, and test framework (GUT)

## F-0002: ChessBoardDisplay
- Parent: none
- Dependencies: F-0001
- Status: planned
- Acceptance: spec/acceptance/F-0002.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Render 8x8 chess board with alternating colors, coordinate labels, and responsive layout

## F-0003: PieceMovementRules
- Parent: none
- Dependencies: F-0002
- Status: in_progress
- Acceptance: spec/acceptance/F-0003.md
- Implementation:
  - State: partial
  - Files: src/game/piece.gd, src/game/board.gd
- Tests:
  - Unit: partial (tests/unit/test_piece.gd, tests/unit/test_board.gd)
- Description: Implement movement rules for all six chess piece types (King, Queen, Rook, Bishop, Knight, Pawn) including captures

## F-0004: PieceArrivalSystem
- Parent: none
- Dependencies: F-0003
- Status: in_progress
- Acceptance: spec/acceptance/F-0004.md
- Implementation:
  - State: partial
  - Files: src/game/piece_arrival.gd
- Tests:
  - Unit: todo
- Description: System for pieces to arrive one-by-one with next piece preview, column selection, and configurable arrival frequency

## F-0005: GameLoopAndTurns
- Parent: none
- Dependencies: F-0003, F-0004
- Status: in_progress
- Acceptance: spec/acceptance/F-0005.md
- Implementation:
  - State: partial
  - Files: src/game/game_state.gd
- Tests:
  - Unit: todo
- Description: Two-player turn system with check detection, checkmate detection, stalemate handling, and game over conditions

## F-0006: SaveLoadSystem
- Parent: none
- Dependencies: F-0005
- Status: planned
- Acceptance: spec/acceptance/F-0006.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Persist game state to JSON, restore games, autosave functionality

## F-0007: SettingsMenu
- Parent: none
- Dependencies: F-0001
- Status: planned
- Acceptance: spec/acceptance/F-0007.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Configure game options: piece arrival frequency, arrival order mode (fixed/selectable/random), special rules toggle

## F-0008: AIOpponent
- Parent: none
- Dependencies: F-0005
- Status: planned
- Acceptance: spec/acceptance/F-0008.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Computer opponent using minimax algorithm with configurable difficulty

## F-0009: MoveHistoryNavigation
- Parent: none
- Dependencies: F-0005
- Status: planned
- Acceptance: spec/acceptance/F-0009.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: View move history, navigate back/forward through moves (like chess.com analysis)

## F-0010: ArrowDrawing
- Parent: none
- Dependencies: F-0002
- Status: planned
- Acceptance: spec/acceptance/F-0010.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Draw arrows on board for planning moves (right-click drag like chess.com)

## F-0011: SpecialChessRules
- Parent: F-0003
- Dependencies: F-0003
- Status: planned
- Acceptance: spec/acceptance/F-0011.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Implement castling, en passant, pawn promotion

## F-0012: PhysicsBumpMode
- Parent: none
- Dependencies: F-0003
- Status: shipped
- Acceptance: spec/acceptance/F-0012.md
- Implementation:
  - State: complete
  - Files: src/ui/board/piece_sprite.gd, src/game/board.gd, src/ui/board/board_view.gd, src/systems/settings.gd
- Tests:
  - Unit: N/A (visual feature)
- Description: Optional visual mode where captured pieces are bumped off with physics animation

## F-0013: RowClearRule
- Parent: none
- Dependencies: F-0003
- Status: planned
- Acceptance: spec/acceptance/F-0013.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Description: Optional Tetris-style rule: three pawns in a row clears the row
