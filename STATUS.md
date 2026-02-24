# STATUS.md

<!-- format: status-v0.2.0 -->

## Project Phase: building

## In Progress

- None

## Next Tasks (Priority)

1. **Save/Load** - Persist game state, autosave functionality
2. **Settings menu** - Configure arrival frequency, game modes, piece set toggle
3. **Clock UI** - Display timer mode countdown in game
4. **Game rules screen** - Viewable from main menu link
5. **Move history export** - Copy movement history as text for debugging/sharing

## Backlog

- **Real 3D rendering** - Use actual 3D models with camera/lighting instead of 2D sprites
- **AI pawn sacrifice fix** - AI sometimes sacrifices 3 pawns needlessly; make this only happen on Easy difficulty

---

## Current State (2026-01-27)

- Game is playable at: https://tomgun.github.io/saktris-game/
- GitHub repo: https://github.com/tomgun/saktris-game (public)
- Turn logic: Place a piece OR move a piece (not both)
- Features working:
  - Two-player, vs AI, and Action Mode (real-time)
  - Piece arrival system (frequency-based, auto-arrival in action mode)
  - Physics bump animations with collision sparks
  - Motion trails for long-distance slider moves
  - Hovering piece placement UX
  - Drag-and-drop AND click-to-move piece movement
  - Arrow drawing for move planning (right-click drag, L-shaped for knights)
  - Web export with GitHub Pages deployment (custom HTML shell)
  - Both Black and White arrival areas visible
  - Proper checkmate/king capture detection
  - Game title and credit on main screen
  - Threaded AI calculation (background thread keeps UI/animations smooth)
  - Sound FX system with theme support (move, capture, place, check, checkmate sounds)
  - Draw detection (50-move rule, threefold repetition, insufficient material)
  - Timer mode (chess clock with various time controls)
  - Multiple piece sets (standard flat, spatial 3D-style)
  - Mobile responsive layout with touch input support
  - Triplet clear rule (3-in-a-row clears pieces)
  - Action Mode with per-player cooldowns, auto-arrivals, bump mechanics

## Known Issues
- See `spec/ISSUES.md` (2 open: I-0001 board size, I-0002 landscape rotation)

## Completed Features
- F-0001: Godot project structure
- F-0002: Chess board UI (click-to-move + drag-and-drop)
- F-0003: Chess piece movement rules
- F-0004: Piece arrival system
- F-0005: Turn system with checkmate detection
- F-0008: AI opponent
- F-0010: Arrow drawing for move planning
- F-0011: Special chess rules (castling, en passant, promotion)
- F-0012: Physics bump mode (sparks + motion trails)
- F-0013: Triplet clear rule (3-in-a-row)
- F-0014: Bishop placement rule
- F-0015: Sound FX & Theme System
- F-0016: Timer Mode (chess clock)
- F-0017: Draw Rules (50-move, repetition, insufficient material)
- F-0018: Multiple Piece Sets (standard, spatial 3D)
- F-0019: Mobile View (responsive layout + touch input)
- F-0022: Action Mode (real-time gameplay with cooldowns)
- Web deployment pipeline
