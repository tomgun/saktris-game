# STATUS.md

## Next Tasks (Priority)

1. **Piece visuals** - Make pieces look more 3D with shading (skins optional/future)
2. **Save/Load** - Persist game state, autosave functionality
3. **Settings menu** - Configure arrival frequency, game modes

---

## Current State (2026-01-08)

- Game is playable at: https://tomgun.github.io/saktris-game/
- GitHub repo: https://github.com/tomgun/saktris-game (public)
- Turn logic: Place a piece OR move a piece (not both)
- Features working:
  - Two-player and vs AI modes
  - Piece arrival system (frequency-based)
  - Physics bump animations with collision sparks
  - Motion trails for long-distance slider moves
  - Hovering piece placement UX
  - Drag-and-drop AND click-to-move piece movement
  - Arrow drawing for move planning (right-click drag)
  - Web export with GitHub Pages deployment
  - Both Black and White arrival areas visible
  - Proper checkmate/king capture detection
  - Game title and credit on main screen

## Known Issues
- None critical

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
- F-0014: Bishop placement rule
- Web deployment pipeline
