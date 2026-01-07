# PRD - Saktris

Purpose: define *why* we're building this and *what* success means.

## Summary
- Problem (1-2 sentences): Traditional chess has a high barrier to entry and games follow predictable opening patterns. We want a fresh take on chess that adds strategic variety through dynamic piece introduction.
- Target user: Chess enthusiasts looking for a new challenge, puzzle game fans, casual gamers who find chess too intimidating
- Primary workflow: Start game -> place incoming pieces strategically -> move pieces with chess rules -> capture opponents -> achieve victory condition

## Goals (measurable)
- G1: Create a playable MVP with two-player local mode within first development phase
- G2: Achieve 60 FPS performance on mid-range mobile devices (2020+ phones)
- G3: Support Web, iOS, and Android platforms from single codebase
- G4: Enable save/resume for interrupted games

## Non-goals (explicit)
- NG1: No online multiplayer in v1 (design for it, implement later)
- NG2: No advanced AI (neural network / ML-based) in v1
- NG3: No monetization features (ads, IAP) in v1
- NG4: No social features (friends, chat, leaderboards) in v1

## Requirements (user-facing)
- R-0001: User can play a complete game of Saktris against another local player
- R-0002: User can see which piece is coming next
- R-0003: User can choose which column to place incoming pieces
- R-0004: All chess pieces move according to standard chess rules
- R-0005: User can save and resume games
- R-0006: User can configure game settings (piece arrival rate, order mode)
- R-0007: User can play against a computer opponent

## Acceptance criteria (high-level)
- AC1: Two players can complete a full game on a single device
- AC2: Piece arrival system works with configurable frequency
- AC3: All six chess piece types have correct movement and capture behavior
- AC4: Check and checkmate are correctly detected
- AC5: Game state persists across app restarts

## Feature mapping (IDs)
- Feature registry: `spec/FEATURES.md`
- Map requirements to features:
  - R-0001 -> F-0001 (Godot project), F-0002 (board), F-0003 (pieces), F-0005 (game loop)
  - R-0002 -> F-0004 (arrival system)
  - R-0003 -> F-0004 (arrival system)
  - R-0004 -> F-0003 (piece movement)
  - R-0005 -> F-0006 (save/load)
  - R-0006 -> F-0007 (settings)
  - R-0007 -> F-0008 (AI opponent)

## Risks & open questions
- Risk: Chess engine complexity (en passant, castling, promotion) may take longer than expected
- Risk: Mobile performance may require optimization work
- Question: What happens when all back-row columns are occupied and a piece needs to arrive?
- Question: Should there be alternative victory conditions beyond checkmate?
- Question: How to handle stalemate in Saktris context?

## Release plan (thin)
- Milestone 1 (MVP): Two-player local gameplay with all chess rules, basic UI
- Milestone 2: AI opponent, settings, polish
- Milestone 3: Mobile deployment (iOS, Android)
- Milestone 4: Online multiplayer (future)
