# STATUS.md

## Next Tasks (Priority)

1. **Board positioning** - Move board so arriving BLACK pieces are visible too (currently only white's arrival area shows below board)
2. **Game title** - Display "SAKTRIS" somewhere on the game screen (small is ok)
3. **Collision VFX** - Add spark/particle effects when pieces collide during physics bump
4. **Piece visuals** - Make pieces look more 3D with shading (skins optional/future)
5. **Drag and drop** - Allow dragging pieces to move them (keep click-to-select as alternative)

---

## Current State (2026-01-07)

- Game is playable at: https://tomgun.github.io/saktris-game/
- GitHub repo: https://github.com/tomgun/saktris-game (public)
- Turn logic: Place a piece OR move a piece (not both)
- Features working:
  - Two-player and vs AI modes
  - Piece arrival system (frequency-based)
  - Physics bump animations
  - Hovering piece placement UX
  - Web export with GitHub Pages deployment

## Known Issues
- Black's arrival area (above board) not visible - board needs repositioning
- No in-game title display

## Completed Features
- F-0001: Godot project structure
- F-0002: Chess board UI
- F-0003: Chess piece movement rules
- F-0004: Piece arrival system
- F-0005: Turn system
- F-0011: AI opponent
- F-0012: Physics bump mode
- Web deployment pipeline
