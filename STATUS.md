# STATUS.md

<!-- format: status-v0.2.0 -->

## Project Phase: building

## In Progress

- F-0023: Online Action Mode Fixes & Ready Button - implemented, ready for testing

## Next Tasks (Priority)

1. **Save/Load (F-0006)** - Persist game state, autosave functionality
2. **Settings menu completion (F-0007)** - Add arrival config, piece set, theme, volume controls
3. **Game rules screen (F-0020)** - Viewable from main menu link
4. **Move history navigation (F-0009)** - Navigate through move history, board state replay
5. **Mobile bug fixes (F-0019)** - I-0001 board size, I-0002 landscape rotation

## Backlog

- **Real 3D rendering** - Use actual 3D models with camera/lighting instead of 2D sprites
- **AI pawn sacrifice fix** - AI sometimes sacrifices 3 pawns needlessly; make this only happen on Easy difficulty

---

## Current State (2026-02-27)

- Game is playable at: https://tomgun.github.io/saktris-game/
- GitHub repo: https://github.com/tomgun/saktris-game (public)
- Turn logic: Place a piece OR move a piece (not both)
- Features working:
  - Two-player, vs AI, and Action Mode (real-time)
  - Online multiplayer (WebRTC P2P with room codes)
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
  - Mobile responsive layout with touch input support (partial - known bugs)
  - Triplet clear rule (3-in-a-row clears pieces)
  - Action Mode with per-player cooldowns, auto-arrivals, bump mechanics
  - Online action mode with ready button, game mode sync, random side option
  - Settings menu (player name, game style)

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
- F-0021: Online Multiplayer (WebRTC P2P)
- F-0022: Action Mode (real-time gameplay with cooldowns)
- F-0023: Online Action Mode Fixes & Ready Button
- Web deployment pipeline

## Partially Complete
- F-0007: Settings Menu (basic - name, game style; missing: arrival config, piece set, theme, volume)
- F-0019: Mobile View (responsive layout + touch works; bugs: board size in portrait, landscape rotation)
