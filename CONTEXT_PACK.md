# CONTEXT_PACK.md

Purpose: a compact, durable starting point for any agent/human so they don't need to reread the whole repo.

## One-minute overview
- What this repo is: Saktris - a chess+tetris hybrid board game built with Godot 4.3. Pieces arrive one-by-one onto a chess board (like Tetris blocks) rather than starting pre-placed.
- Main user workflow:
  - Select column for incoming piece placement
  - Move pieces using standard chess rules
  - Capture opponent pieces, achieve checkmate
- Current top priorities:
  - Set up Godot project structure
  - Implement core chess piece movement rules
  - Create basic board visualization
  - Implement piece arrival system

## Where to look first (map)
- Entry points: `project.godot`, `src/main.tscn`
- Core modules:
  - `src/game/` - Game logic (rules engine, board state, pieces)
  - `src/ui/` - Visual representation (board view, piece sprites)
  - `src/ai/` - AI opponent logic
  - `src/systems/` - Save/load, settings
- Specs: `/spec/`
- Features: `spec/FEATURES.md`
- Overview: `spec/OVERVIEW.md`
- Non-functional requirements: `spec/NFR.md`
- Lessons: `spec/LESSONS.md`
- Decisions: `spec/adr/`
- Status: `STATUS.md`
- Game rules: `docs/CHESS_RULES.md`, `docs/SAKTRIS_RULES.md`

## How to run
- Setup: Install Godot 4.3+ from https://godotengine.org/download
- Godot path (macOS): `/Applications/Godot.app/Contents/MacOS/Godot`
- Run: Open `project.godot` in Godot, press F5
- Test: `/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_file.gd`
- Test all: `/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`

## Architecture snapshot
- Components:
  - **GameState**: Core game loop, turn management, win conditions
  - **Board**: 8x8 grid, piece positions, move validation
  - **Piece**: Movement rules per type (King, Queen, Rook, Bishop, Knight, Pawn)
  - **PieceArrivalManager**: Queues incoming pieces, handles arrival order modes
  - **BoardView**: Visual rendering of board and pieces
  - **AI**: Computer opponent (basic minimax or random)
- Data flow:
  - User input -> GameState -> Board (validate move) -> BoardView (animate)
  - AI turn -> AI -> GameState -> Board -> BoardView
- External dependencies: None for v1 (fully offline)

## Quality gates (current)
- Unit tests required: yes
- Definition of Done: see `.agentic/workflows/definition_of_done.md`
- Review checklist: see `.agentic/quality/review_checklist.md`

## Known risks / sharp edges
- Chess rule edge cases (en passant, castling, promotion) need careful testing
- Physics "bump" mode may have performance implications on mobile
- AI difficulty balancing will require playtesting iteration
