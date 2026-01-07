# Saktris Rules

**Saktris** (from Finnish "shakki" = chess + Tetris) is a chess variant where pieces arrive dynamically during the game.

## Overview

Unlike traditional chess where all pieces start on the board, Saktris introduces pieces gradually throughout the game. This creates a unique strategic layer where players must balance immediate tactics with long-term piece placement strategy.

## Setup

- Standard 8x8 chess board
- Game begins with **empty board** (no pieces placed)
- Each player has a **piece arrival queue** containing their pieces
- Players can see their **next piece** that will arrive

## Piece Arrival System

### Arrival Timing
- A new piece arrives for a player after every **N moves** (configurable, default: 1)
- The arrival happens at the **start** of the player's turn
- **Important**: Placing a piece **ends the turn** - you cannot move after placing

### Placement
- When a piece arrives, the player chooses which **column** (a-h) to place it
- The piece is placed on the player's **back row**:
  - White: row 1
  - Black: row 8
- If the chosen column is occupied, placement is blocked (see Blocked Placement)

### Bishop Placement Rule
- A bishop **cannot** be placed on the same color square as an existing bishop of the same player
- This ensures each player has opposite-colored bishops (one on light squares, one on dark squares)
- If your first bishop is on a dark square, your second bishop must go on a light square

### Next Piece Preview
- Players can always see their **next incoming piece**
- This allows strategic planning for placement

### Arrival Order Modes
Three modes for determining piece arrival order:

1. **Fixed/Pre-configured**: Pieces arrive in a set order (good for tutorials, puzzles)
   - Default order: Pawn, Pawn, Knight, Pawn, Bishop, Pawn, Rook, Pawn, Queen, Pawn, Pawn, Knight, Bishop, Rook, Pawn, King

2. **User-selectable**: Player chooses which piece to deploy from available pool

3. **Random**: Pieces arrive in random order
   - Can be same random sequence for both players (fair)
   - Or different random sequences (chaotic mode)

### Piece Pool
Each player has access to the standard chess piece set:
- 1 King
- 1 Queen
- 2 Rooks
- 2 Bishops
- 2 Knights
- 8 Pawns

**Note**: The King must be placed before victory conditions apply. Until a player has their King on the board, they cannot be checkmated.

## Movement Rules

All pieces move according to **standard chess rules** (see docs/CHESS_RULES.md).

### Pawns in Saktris
- Pawns placed on the back row can move forward one or two squares on their first move
- En passant is possible if the conditions are met (pawn advances two squares beside opponent's pawn)
- Pawns reaching the opposite end are promoted (Queen, Rook, Bishop, or Knight)

### Special Moves

**Castling**:
- Allowed if King and Rook have not moved since placement
- Standard castling rules apply (no pieces between, not through check)
- Since pieces don't start in fixed positions, castling might happen in unusual configurations

## Victory Conditions

### Primary: Checkmate
- Standard chess checkmate rules
- A player wins by placing the opponent's King in checkmate
- The opponent's King must be on the board to be checkmated

### No King Clause
- If a player's King has not yet arrived and they lose all their pieces, they lose
- Alternatively, game continues until King arrives (configurable)

## Optional Rules

### Row Clear Rule (Tetris Mode)
- When three or more **pawns of the same color** are aligned in a horizontal row
- All those pawns are **cleared from the board** (removed)
- This adds a Tetris-like element - avoid lining up your own pawns!

### Physics Bump Mode
- Visual enhancement only, does not affect gameplay
- When a piece is captured, it is "bumped" off the board with physics animation
- Remaining pieces smoothly return to their positions

## Blocked Placement

When a piece needs to arrive but all columns on the back row are occupied:

**Option A - Skip** (default):
- The piece arrival is skipped for this turn
- The piece remains in queue and will attempt to arrive next scheduled time

**Option B - Queue**:
- Piece waits until a column opens
- Multiple pieces can queue up

**Option C - Force**:
- Player must make space (move a piece) before their move
- If impossible, they forfeit their regular move

## Game Settings Summary

| Setting | Options | Default |
|---------|---------|---------|
| Arrival Frequency | 1-5 moves | 1 move |
| Arrival Order | Fixed, Selectable, Random | Random (same) |
| Random Mode | Same for both, Different | Same |
| Blocked Placement | Skip, Queue, Force | Skip |
| Row Clear Rule | On/Off | Off |
| Physics Bump | On/Off | Off |
| Bishop Placement Rule | Always On | On |

## Strategy Tips

1. **Control the center early** - Place pieces that can influence central squares
2. **King safety** - Don't place your King until you have defenders ready
3. **Column control** - Keep back row columns open for future placements
4. **Pawn structure** - Be mindful of the Row Clear Rule if enabled
5. **Tempo** - Piece arrivals give free "development" - use this advantage

## Differences from Standard Chess

| Aspect | Standard Chess | Saktris |
|--------|---------------|---------|
| Starting position | All 16 pieces placed | Empty board |
| Piece introduction | All at game start | Gradual arrival |
| Opening theory | Extensive | None (new game each time) |
| King exposure | Always on board | Arrives during game |
| Strategic planning | Position-based | Position + arrival timing |
