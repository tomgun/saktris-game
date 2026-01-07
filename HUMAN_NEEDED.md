# HUMAN_NEEDED

<!-- format: human-needed-v0.1.0 -->

**Purpose**: Track items requiring human input, decisions, or intervention that agents cannot reasonably handle.

📖 **For examples and guidelines, see:** `.agentic/spec/HUMAN_NEEDED.reference.md`

---

## Active items needing attention

### HN-0002: Decide victory conditions (ADR-0001)
- **Type**: Design decision
- **Context**: Need to finalize how games end in Saktris
- **Why human needed**: Game design decision with multiple valid approaches
- **Options**:
  - A) Checkmate only (standard chess)
  - B) Checkmate OR eliminate all pieces (if king not yet placed)
  - C) Point-based (capture value) with time limit
- **Impact**: Affects game_state.gd win condition logic
- **Blocking**: F-0005 completion

### HN-0003: Decide blocked placement behavior (ADR-0002)
- **Type**: Design decision
- **Context**: What happens when a piece arrives but all back-row columns are occupied?
- **Why human needed**: Gameplay feel decision
- **Options**:
  - A) Skip arrival, piece stays in queue (default)
  - B) Force player to make space first
  - C) Game over / forfeit
- **Impact**: Affects piece_arrival.gd logic
- **Blocking**: F-0004 completion

---

## Resolved

### HN-0001: Install GUT test framework
- **Resolved**: 2026-01-05
- **Outcome**: GUT installed via Asset Library and enabled
