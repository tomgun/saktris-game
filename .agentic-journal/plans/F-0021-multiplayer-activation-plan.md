# Plan: Get Online Multiplayer Working (F-0021 Activation)

## Context
All the P2P multiplayer code for Saktris (F-0021) is already written (~1,150 lines across 4 networking files + UI + signaling server). The architecture uses WebRTC for P2P game data and a minimal signaling server only for the initial handshake. However, multiplayer can't actually be played because:

1. **Critical bug**: The WebRTC data channel received signal is never connected for the guest player
2. **Signaling server not deployed**: URL is still a placeholder
3. **Never been end-to-end tested**

## Architecture (already implemented)

```
Player 1 <--WebSocket--> Signaling Server <--WebSocket--> Player 2
   ^                    (room codes only)                    ^
   └──────────── WebRTC DataChannel (P2P) ──────────────────┘
                    (all game data flows here)
```

### Existing files
| Component | File | Lines |
|-----------|------|-------|
| NetworkManager (autoload) | `src/network/network_manager.gd` | 522 |
| WebRTC P2P client | `src/network/webrtc_client.gd` | 198 |
| Signaling client | `src/network/signaling_client.gd` | 206 |
| Protocol/messages | `src/network/network_protocol.gd` | 225 |
| Multiplayer menu UI | `src/ui/multiplayer/multiplayer_menu.gd` | 216 |
| Multiplayer menu scene | `src/ui/multiplayer/multiplayer_menu.tscn` | 200 |
| Main scene integration | `src/main.gd` | 230 |
| Signaling server | `signaling-server/index.js` | 213 |

## Step 1: Fix WebRTC data_channel_received bug

**File**: `src/network/webrtc_client.gd`

The `_on_data_channel_received` method exists (line 195) but is never connected to the `WebRTCPeerConnection.data_channel_received` signal in `_init()`. This means when the host creates a data channel, the guest will never receive it — breaking the entire connection.

**Fix**: Add `_peer.data_channel_received.connect(_on_data_channel_received)` in `_init()`.

## Step 2: Deploy signaling server to Render

**Files**: `signaling-server/` (Node.js + `ws` library)

The server is a minimal WebSocket relay for room codes and WebRTC signal forwarding. No game logic, no persistence.

**Render setup**:
1. Create a new "Web Service" on Render (render.com)
2. Connect the GitHub repo, set root directory to `signaling-server/`
3. Build command: `npm install`
4. Start command: `npm start`
5. Instance type: Free
6. Render provides a `wss://` URL automatically (e.g., `wss://saktris-signaling.onrender.com`)

**Note**: Netlify was considered but doesn't support persistent WebSocket connections.

## Step 3: Update signaling server URL

**File**: `src/network/network_manager.gd` (line 20)

Replace placeholder:
```gdscript
const SIGNALING_SERVER_URL := "wss://saktris-signaling.your-server.workers.dev"  # TODO: Update with actual URL
```
With the Render URL.

## Step 4: Local end-to-end testing

1. Run signaling server locally: `cd signaling-server && npm start`
2. Temporarily set URL to `ws://localhost:8080`
3. Open two Godot instances (or web export + two browser tabs)
4. Player 1: Create Game → get room code
5. Player 2: Join Game → enter room code
6. Verify: connection established, moves sync, state hashes match
7. Test disconnect handling

## Step 5: Fix any issues found during testing

Likely areas needing attention based on code review:
- Board view refresh after remote moves
- Turn switching after remote actions
- Disconnect handling UI feedback

## Files to modify
- `src/network/webrtc_client.gd` — fix data_channel_received connection (1 line)
- `src/network/network_manager.gd` — update signaling server URL (1 line)
- `signaling-server/` — deploy to Render (no code changes)

## Verification
1. Run signaling server locally first for quick iteration
2. Create room in one client, join from another
3. Play a full game: piece placements, moves, captures
4. Verify state stays in sync (no hash mismatches in console)
5. Test disconnect handling (close one client)
6. Deploy to Render and test with the production URL

## Key design decisions (already made)
- WebRTC for P2P (works in browsers + desktop)
- Room codes: 6-char alphanumeric (no 0/O/1/I)
- Deterministic RNG: shared seed means piece sequences match without sync
- State hash verification: catches divergence, auto-resync via host
- JSON protocol over WebRTC DataChannel (ordered, reliable)
- Google STUN servers for NAT traversal (free, public)
