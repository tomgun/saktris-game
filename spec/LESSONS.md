# Lessons & Caveats

Purpose: prevent repeating mistakes and capture "sharp edges".

---

## L-0001: Web export context menu
- Related: F-0010
- What happened: Right-click arrow drawing triggered browser context menu in web export
- Why it happened: Default HTML template doesn't block context menu
- What to do next time: Use custom HTML shell template with context menu prevention
- Links: export_templates/web_shell.html

## L-0002: Godot SVG import scaling
- Related: F-0002
- What happened: SVG chess pieces rendered at wrong size initially
- Why it happened: Godot SVG import scale settings differ from file dimensions
- What to do next time: Check import settings, use consistent source sizes
- Links: assets/sprites/pieces/

## L-0003: Audio file import
- Related: F-0015
- What happened: New .ogg files weren't recognized until editor reimport
- Why it happened: Godot needs to generate .import files for new assets
- What to do next time: Run editor (not headless) after adding audio files to trigger import
- Links: assets/audio/themes/

## L-0004: Physics collision spam
- Related: F-0012
- What happened: Collision sparks/sounds fired repeatedly for same collision
- Why it happened: No cooldown between collision events for same piece pair
- What to do next time: Track recent collisions with timestamp-based cooldown
- Links: src/ui/board/board_view.gd:_update_physics()
