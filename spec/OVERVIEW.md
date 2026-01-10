# Overview

Purpose: understand the **vision**, **current state**, and **where to find truth**.

---

## Vocabulary
- **Features (F-####)**: Canonical units of shippable game capabilities with acceptance criteria
- **NFRs (NFR-####)**: Cross-cutting constraints (performance, reliability)
- **Requirements**: Not used separately—captured as feature acceptance criteria

---

## Vision (high level)
- **What are we building**: Saktris - a chess+tetris hybrid where pieces arrive one-by-one onto the board
- **Who is it for**: Casual strategy game players who enjoy chess variants
- **What "success" looks like**: Playable game on web/mobile with unique Tetris-inspired mechanics

## Current state (2026-01-08)
- **Current version**: v0.1.0 (playable alpha)
- **What works**:
  - Two-player and vs AI modes
  - Piece arrival system with configurable frequency
  - All standard chess rules (castling, en passant, promotion)
  - Physics bump animations with collision effects
  - Triplet clear rule (3-in-a-row clearing)
  - Sound effects system
  - Arrow drawing for move planning
- **What's in progress**:
  - Settings menu UI
  - Save/load system
- **What's risky**:
  - Mobile performance (untested)
  - AI difficulty tuning

## Architecture (map)
- **Read**: `spec/TECH_SPEC.md`
- **Entry points**:
  - `src/main.gd` - Game initialization
  - `src/ui/board/board_view.gd` - Main game UI
- **Major components**:
  - `src/game/` - Core game logic (board, pieces, rules, AI)
  - `src/ui/` - User interface components
  - `src/systems/` - Autoloads (settings, audio, themes)

## Feature registry (source of truth)
- **Read**: `spec/FEATURES.md`
- 15 features defined (11 shipped, 4 planned)
- Each feature has acceptance criteria in `spec/acceptance/`

## Lessons & caveats
- **Read**: `spec/LESSONS.md` and `spec/adr/`
