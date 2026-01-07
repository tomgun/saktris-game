# Chess Rules Reference

This document provides a reference for standard chess rules used as the foundation for Saktris.

## The Board

- 8x8 grid of alternating light and dark squares
- Columns labeled a-h (left to right from White's perspective)
- Rows labeled 1-8 (bottom to top from White's perspective)
- White pieces traditionally start on rows 1-2, Black on rows 7-8

## The Pieces

### King (K)
- Moves one square in any direction (horizontal, vertical, diagonal)
- Cannot move into check
- Special move: Castling (see below)
- Most valuable piece - game ends when checkmated

### Queen (Q)
- Moves any number of squares horizontally, vertically, or diagonally
- Cannot jump over other pieces
- Most powerful piece

### Rook (R)
- Moves any number of squares horizontally or vertically
- Cannot jump over other pieces
- Participates in castling

### Bishop (B)
- Moves any number of squares diagonally
- Cannot jump over other pieces
- Each bishop stays on its starting color for the entire game

### Knight (N)
- Moves in an "L" shape: 2 squares in one direction, then 1 square perpendicular
- The only piece that can jump over other pieces
- Always lands on opposite color square from starting position

### Pawn (P)
- Moves forward one square (toward opponent's side)
- On first move, can optionally move forward two squares
- Captures diagonally forward one square
- Cannot move backward
- Special moves: En passant, Promotion (see below)

## Captures

- A piece captures by moving to a square occupied by an opponent's piece
- The captured piece is removed from the board
- Exception: Pawns capture diagonally, not in their normal movement direction

## Special Moves

### Castling
Requirements:
- Neither the King nor the Rook has moved previously
- No pieces between the King and Rook
- King is not currently in check
- King does not pass through or land on a square under attack

Kingside Castling (O-O):
- King moves two squares toward the h-file Rook
- Rook moves to the square the King crossed

Queenside Castling (O-O-O):
- King moves two squares toward the a-file Rook
- Rook moves to the square the King crossed

### En Passant
- When a pawn advances two squares on its first move and lands beside an opponent's pawn
- The opponent's pawn can capture it "in passing" on the next move only
- The capturing pawn moves diagonally to the square the captured pawn passed through
- Must be done immediately on the next move or the right is lost

### Pawn Promotion
- When a pawn reaches the opposite end of the board (row 8 for White, row 1 for Black)
- It must be promoted to Queen, Rook, Bishop, or Knight
- Usually promoted to Queen (most powerful)

## Check and Checkmate

### Check
- When a King is under attack by an opponent's piece
- The player in check must get out of check on their next move
- Ways to escape check:
  1. Move the King to a safe square
  2. Block the attack with another piece
  3. Capture the attacking piece

### Checkmate
- When a King is in check and has no legal moves to escape
- The game ends immediately - the player delivering checkmate wins

### Stalemate
- When a player has no legal moves but is NOT in check
- The game ends in a draw

## Other Draw Conditions

- **Agreement**: Both players agree to a draw
- **Threefold Repetition**: Same position occurs three times with same player to move
- **50-Move Rule**: 50 consecutive moves by each player without a pawn move or capture
- **Insufficient Material**: Neither player has enough pieces to checkmate (e.g., King vs King)

## Notation

Standard algebraic notation:
- Piece letter (K, Q, R, B, N) + destination square (e.g., Nf3)
- Pawn moves omit the piece letter (e.g., e4)
- Captures indicated by "x" (e.g., Bxe5)
- Check indicated by "+" (e.g., Qh7+)
- Checkmate indicated by "#" (e.g., Qh7#)
- Castling: O-O (kingside), O-O-O (queenside)
