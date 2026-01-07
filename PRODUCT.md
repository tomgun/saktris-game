# PRODUCT.md

Purpose: what we're building, what's done, and what's next. No ceremony, no IDs, just shared context for humans + agents.

## What we're building

**Saktris** (from Finnish "shakki" = chess + Tetris) is a strategic board game that combines chess mechanics with Tetris-style piece delivery. Unlike traditional chess where all 16 pieces start on the board, pieces arrive one-by-one throughout the game.

Players see their next incoming piece and choose which column to place it on their back row. A new piece arrives after a configurable number of moves. The game uses standard chess piece movement rules, but with unique victory conditions and optional special rules like row-clearing (three pawns in a row = Tetris-style clear).

The game should feel like playing on chess.com - clean, elegant board visualization with move arrows, move history navigation, and smooth animations. An optional "physics mode" adds visual flair where pieces bump each other with physics-based animations.

## Core capabilities
- [ ] Standard chess board display (8x8, alternating colors)
- [ ] All six chess piece types with correct movement/capture rules
- [ ] Piece arrival system (one piece appears on back row per N moves)
- [ ] Next piece preview (shows what's coming next)
- [ ] Column selection for incoming pieces
- [ ] Piece arrival order modes: pre-configured, user-selectable, random (same/different for players)
- [ ] Move history with navigation (back/forward through moves)
- [ ] Arrow drawing on board (for planning, like chess.com)
- [ ] Two-player local mode (same device, alternating turns)
- [ ] Single-player vs AI opponent
- [ ] Game settings (piece arrival frequency, order mode, special rules)
- [ ] Optional: Row-clear rule (3 pawns in a row = clear)
- [ ] Optional: Physics bump animation mode
- [ ] Saved games / resume
- [ ] Future: Online multiplayer

## Technical approach
- Stack: Godot 4.3 (GDScript)
- Architecture: Scene-based (Godot standard), with separation of game logic from presentation
- Key decisions:
  - Use Godot for cross-platform (Web/iOS/Android) from single codebase
  - Separate game rules engine from UI for testability
  - Store game state in a serializable format for save/load and future network sync

## In scope (for now)
- Local two-player gameplay
- Basic AI opponent (random or simple minimax)
- Core chess mechanics with piece arrival system
- Clean chess.com-style UI
- Web browser playable version

## Out of scope (for now)
- Online multiplayer (design for it, but don't implement yet)
- Advanced AI (neural network / deep learning)
- Ranked matchmaking
- In-app purchases
- Social features (friends, chat)

## Rough phases
1. **MVP**: Two-player local game with basic UI, all piece movement, piece arrival system
2. **Next**: AI opponent, settings menu, arrow drawing, move history navigation
3. **Later**: Physics mode, mobile builds, online multiplayer infrastructure

## Notes
- Finnish connection: "shakki" means chess in Finnish - keep this heritage in branding
- Reference docs/CHESS_RULES.md and docs/SAKTRIS_RULES.md for game mechanics
- Design with deterministic game logic (enables replay and network sync)
