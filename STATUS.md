# STATUS.md

<!-- format: status-v0.1.0 -->

Purpose: the living "truth" of where the project is today.

## Current session state
- Session: 2026-01-05
- Feature: Project initialization
- Phase: setup
- Completed this session:
  - Agentic framework initialized with Core+PM profile
  - STACK.md filled with Godot 4.3 stack
  - PRODUCT.md filled with game concept
  - CONTEXT_PACK.md filled with architecture overview
  - spec/ documents created
- Next immediate step:
  - Create Godot project structure
- Blockers:
  - None

## Current focus
- Project initialization and documentation setup
- Planning initial feature set

## In progress
- Project setup and scaffolding

## Next up
- F-0001: Create Godot project with folder structure
- F-0002: Implement chess board display
- F-0003: Implement chess piece movement rules
- F-0004: Implement piece arrival system

## Roadmap (lightweight)
- Near-term:
  - Basic chess board with pieces
  - All piece movement rules working
  - Two-player local gameplay
  - Piece arrival system
  - Basic win condition (checkmate)
- Later:
  - AI opponent
  - Settings and game modes
  - Arrow drawing and move history
  - Physics bump animations
  - Mobile deployment
  - Online multiplayer

## Known issues / risks
- Chess rule edge cases (en passant, castling, pawn promotion) need careful implementation
- Godot 4.3 web export may have browser compatibility issues
- Physics mode performance on mobile needs testing

## Decisions needed
- ADR-0001: Exact victory conditions for Saktris (checkmate? point-based? time-based?)
- ADR-0002: What happens when a player can't place an incoming piece (all columns blocked)?
- ADR-0003: Should pawns promote when reaching the opposite end?
