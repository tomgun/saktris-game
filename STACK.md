# STACK.md

<!-- format: stack-v0.1.0 -->

Purpose: a single source of truth for "how we build and run software here".

## Agentic framework
- Version: 0.33.2
- Profile: formal
- Installed: 2026-01-08
- Source: https://github.com/tomgun/agentic-framework

## Summary
- What are we building: Saktris - a chess+tetris hybrid board game where pieces arrive one-by-one onto a chess board
- Primary platform: Multi-platform (Web, iOS, Android)

## Languages & runtimes
- Language(s): GDScript (primary), potentially C# for complex logic
- Runtime(s): Godot 4.5+
- Specific versions: Godot 4.5.1

## Frameworks & libraries
- Game engine: Godot 4.5.1
- UI framework: Godot built-in Control nodes
- Physics: Godot built-in 2D physics (for piece bump animations)
- Animation: Godot AnimationPlayer + Tweens

## Documentation sources
- Godot: https://docs.godotengine.org/en/stable/
- GDScript: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/

## Tooling
- Package manager: Godot Asset Library (for plugins), git-lfs (for large assets)
- Formatting/linting: GDScript formatter (built-in), gdlint (optional)

## License

- **Project License**: Proprietary
- **License File**: `LICENSE` (to be created)
- **Copyright**: 2026 Tomas
- **Compatible Dependencies**: MIT, Apache 2.0, BSD, CC0 (for assets)
- **Incompatible Dependencies**: GPL, AGPL, LGPL (static linking) - agent must avoid these!
- **Asset Licensing**: See `assets/ATTRIBUTION.md` for all external assets

**Note**: Godot engine itself is MIT licensed - safe for proprietary games.

---

## Testing (required)
- Unit test framework: GUT (Godot Unit Test) or gdUnit4
- Integration/E2E (optional): Godot scene testing
- Test commands:
  - Unit: `godot --headless --script res://tests/run_tests.gd`
  - Integration: `godot --headless --script res://tests/run_integration.gd`
  - E2E: Manual playtesting + recorded input replay (future)

## Development approach
- development_mode: tdd

## Sequential agent pipeline
- pipeline_enabled: no
- pipeline_mode: manual
- pipeline_agents: standard
- pipeline_handoff_approval: yes
- pipeline_coordination_file: .agentic/pipeline

## Git workflow (required)
- git_workflow: direct

## Data & integrations
- Primary datastore: Local file (saved games), SQLite (optional for stats)
- Messaging/queues (if any): N/A (future: WebSocket for online multiplayer)
- External integrations:
  - Future: Online multiplayer server
  - Future: Leaderboards (Game Center, Google Play Games)

## Deployment
- Target environment:
  - Web: itch.io, own website (HTML5 export)
  - Mobile: App Store (iOS), Google Play (Android)
  - Desktop: Steam (optional future)
- CI: GitHub Actions
- Release strategy: Semantic versioning (major.minor.patch)

## Constraints & non-negotiables
- Security/compliance: No PII collected in v1 (local play only)
- Performance: 60 FPS on mid-range devices (2020+ phones)
- Reliability: Autosave game state to prevent progress loss

## Quality validation
- quality_checks: enabled
- profile: game_2d_mobile
- pre_commit_hook: fast  # fast | full | no
- run_command: bash quality_checks.sh --pre-commit
- full_suite_command: bash quality_checks.sh --full

## Quality thresholds (game-specific)
- target_fps: 60
- max_frame_time_ms: 16.6
- max_memory_mb: 200 (mobile)
- max_apk_size_mb: 50
- max_html5_size_mb: 30

## Complexity limits
- max_files_per_commit: 10
- max_added_lines: 500
- max_code_file_length: 500

## Settings
<!-- Use `ag set <key> <value>` to change, `ag set --show` to view all. -->
- feature_tracking: yes
- acceptance_criteria: blocking
- wip_before_commit: blocking
- pre_commit_checks: full
- plan_review_enabled: yes
- spec_directory: yes
- docs_gate: blocking
- max_code_file_length: 900
- git_workflow: direct
