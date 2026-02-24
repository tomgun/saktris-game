# Action Saktris - Game Mode Concept

## Overview

Real-time variant where pieces arrive automatically and players can move independently on cooldowns. Unlike Tetris, arriving pieces aren't "the enemy" - they're resources on a shared board.

## Core Mechanics

### Move System
- No turn-based restrictions
- Each player has a **move cooldown** (configurable, e.g., 2-5 seconds)
- After moving, player must wait for cooldown before next move
- Both players can move simultaneously

### Piece Arrival
- Pieces auto-place at **arrival interval** (configurable, e.g., every 5-10 seconds)
- Arrives on the player's back row (alternating white/black, or simultaneous)
- If no valid placement spot, piece is lost or game ends (TBD)

### Piece Selection Methods (configurable)
1. **Predefined sequence**: Fixed order set at game start
2. **Random sequence**: Shuffled order generated at game start (bag system like Tetris)
3. **Weighted random**: Each piece type has probability weight
4. **Per-player config**: Each player can have different piece generation rules

## Win Condition

- **Capture the king** (same as regular Saktris)
- Triplet clears still apply

## Possible Sub-Modes

| Mode | Move Cooldown | Arrival Rate | Notes |
|------|---------------|--------------|-------|
| Blitz | 1-2 sec | 3-5 sec | Frantic, fast decisions |
| Standard | 3-4 sec | 8-10 sec | Balanced real-time |
| Strategic | 5-10 sec | 15-20 sec | More thinking time |
| Survival | 3 sec | Accelerating | Pieces come faster over time |

## Key Difference from Tetris

In Tetris, falling pieces are obstacles you manage. In Action Saktris:
- Pieces are **resources** that strengthen your position
- The opponent also receives pieces
- Strategic tension: fast moves vs. waiting for better position
- Triplet clears can hurt OR help depending on timing

## Open Questions

- [ ] What happens if back row is full when piece arrives?
- [ ] Should triplet clears have a brief "freeze" for both players?
- [ ] Countdown indicator for next piece arrival?
- [ ] Visual indicator for move cooldown?
- [ ] Can you "bank" moves or always use-it-or-lose-it?

## Configuration Parameters

```gdscript
var action_mode_settings = {
    "move_cooldown_white": 3.0,      # seconds
    "move_cooldown_black": 3.0,      # seconds
    "arrival_interval": 8.0,          # seconds between pieces
    "arrival_acceleration": 0.0,      # reduce interval over time
    "piece_selection": "weighted",    # "sequence", "random_bag", "weighted"
    "piece_weights": {
        "pawn": 40,
        "knight": 20,
        "bishop": 20,
        "rook": 15,
        "queen": 5
    },
    "separate_player_queues": false   # same or different pieces per player
}
```
