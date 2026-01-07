# TECH_SPEC - Saktris

Purpose: define *how* we will build it with enough clarity to implement incrementally and testably.

## Scope
- In scope:
  - Core game logic (board, pieces, movement rules)
  - Piece arrival system
  - Two-player local mode
  - Basic AI opponent
  - Save/load system
  - Settings configuration
  - UI for gameplay
- Out of scope:
  - Online multiplayer (designed for, not implemented)
  - Advanced AI
  - Physics bump animations (later phase)

## Features in scope (IDs)
- Feature registry: `spec/FEATURES.md`
- Implemented by this spec:
  - F-0001: Godot project setup
  - F-0002: Chess board display
  - F-0003: Piece movement rules
  - F-0004: Piece arrival system
  - F-0005: Game loop and turns
  - F-0006: Save/load
  - F-0007: Settings
  - F-0008: AI opponent

## Architecture overview
- Style: Modular monolith (single Godot project with clear module boundaries)
- Key constraints from `STACK.md`:
  - 60 FPS target
  - <200MB memory on mobile
  - Deterministic game logic for replay/sync
- Diagrams: docs/architecture/diagrams/

## Components (responsibilities + boundaries)

### GameState (src/game/game_state.gd)
- Responsibilities:
  - Manage current player turn
  - Coordinate piece arrival timing
  - Detect check, checkmate, stalemate
  - Track move history
  - Emit signals for UI updates
- Inputs/outputs:
  - Input: Player moves, piece placements
  - Output: Signals (turn_changed, check_detected, game_over, etc.)
- Test seam: Pure logic, no Godot scene dependencies

### Board (src/game/board.gd)
- Responsibilities:
  - Store piece positions (8x8 grid)
  - Validate move legality
  - Execute moves and captures
  - Generate legal moves for a piece
- Inputs/outputs:
  - Input: Piece, source position, target position
  - Output: Move result (valid/invalid, captures, special moves)
- Test seam: Pure data structure, fully unit-testable

### Piece (src/game/piece.gd)
- Responsibilities:
  - Define piece type (King, Queen, Rook, Bishop, Knight, Pawn)
  - Define movement patterns
  - Track piece state (has_moved for castling, etc.)
- Inputs/outputs:
  - Input: Current position, board state
  - Output: List of potential moves
- Test seam: Movement calculation is pure function

### PieceArrivalManager (src/game/piece_arrival.gd)
- Responsibilities:
  - Maintain arrival queue for each player
  - Track arrival timing (every N moves)
  - Support order modes (fixed, selectable, random)
- Inputs/outputs:
  - Input: Game settings, move count
  - Output: Next piece to arrive, arrival trigger
- Test seam: Queue logic independent of UI

### BoardView (src/ui/board_view.gd)
- Responsibilities:
  - Render board and pieces visually
  - Handle input (click/touch on squares)
  - Animate piece movements
  - Show legal move indicators
- Inputs/outputs:
  - Input: Board state, user input events
  - Output: Move requests to GameState
- Test seam: Can be tested with mock Board

### AI (src/ai/basic_ai.gd)
- Responsibilities:
  - Generate moves for computer player
  - Evaluate board positions
  - Select best move (minimax or random)
- Inputs/outputs:
  - Input: Board state, difficulty setting
  - Output: Selected move
- Test seam: Pure function over board state

## Data model / state

### Board State
```gdscript
# 8x8 array, null = empty, Piece object = occupied
var squares: Array[Array]  # [row][col]

# Piece data
class Piece:
    var type: PieceType  # KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN
    var color: Color  # WHITE, BLACK
    var has_moved: bool  # For castling, pawn double-move
```

### Game State
```gdscript
var current_player: Color
var move_count: int
var move_history: Array[Move]
var arrival_queues: Dictionary  # {Color: Array[PieceType]}
var game_status: GameStatus  # PLAYING, CHECK, CHECKMATE, STALEMATE, DRAW
```

### Move
```gdscript
class Move:
    var piece: Piece
    var from_pos: Vector2i
    var to_pos: Vector2i
    var captured: Piece  # null if no capture
    var special: SpecialMove  # NONE, CASTLE_KING, CASTLE_QUEEN, EN_PASSANT, PROMOTION
    var promotion_type: PieceType  # if PROMOTION
```

### Persistence
- Format: JSON for saved games
- Location: `user://saves/` (Godot user directory)
- Contents: Full game state for resume

## Interfaces

### Internal module interfaces

```gdscript
# Board -> GameState
signal move_executed(move: Move)
signal piece_captured(piece: Piece)

# GameState -> UI
signal turn_changed(player: Color)
signal check_detected(player: Color)
signal game_over(result: GameResult)
signal piece_arriving(player: Color, piece_type: PieceType)

# UI -> GameState
func request_move(from: Vector2i, to: Vector2i) -> bool
func request_placement(column: int) -> bool
```

## Error handling & failure modes
- Failure mode: Invalid move attempted
  - Detection: Board.is_valid_move() returns false
  - Handling: Show feedback, don't execute move
  - Test: Unit test all invalid move scenarios
- Failure mode: Save file corrupted
  - Detection: JSON parse error or schema validation fail
  - Handling: Show error, offer to start new game
  - Test: Integration test with malformed save files

## Testing strategy (required)
- Unit tests:
  - All piece movement rules (each piece type)
  - Check detection
  - Checkmate detection
  - Castling legality
  - En passant legality
  - Pawn promotion
  - Piece arrival queue logic
- Integration tests:
  - Complete game scenarios (recorded move sequences)
  - Save/load round-trip
- Non-functional testing:
  - Performance: Frame time profiling on target devices
  - Memory: Heap analysis during extended play

## Risks & open questions
- Risk: Godot 4.3 web export has known issues with some browsers
- Risk: AI difficulty tuning will require iteration
- Question: Exact behavior when arrival is blocked - skip? queue? game over?
- Question: Should we support en passant in Saktris (pieces don't start on board)?
