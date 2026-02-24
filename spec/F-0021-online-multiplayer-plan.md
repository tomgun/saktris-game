# F-0021: Online Multiplayer Implementation Plan

## Overview

Two-phase approach for online multiplayer in Saktris:
- **Phase A**: Browser-to-browser P2P using WebRTC (no game server needed)
- **Phase B**: Server-based matchmaking, accounts, game storage (future)

## Architecture

### Phase A: P2P with Signaling Server

```
Player 1 <--WebSocket--> Signaling Server <--WebSocket--> Player 2
    ^                    (room codes only)                    ^
    └──────────── WebRTC DataChannel (P2P) ──────────────────┘
                      (game messages)
```

- Signaling server only handles room creation and WebRTC handshake
- After connection: direct P2P communication, signaling server not needed
- All game logic runs on both clients, validated independently

### Phase B: Server-Based (Future)

- Matchmaking queue with skill-based matching
- Authoritative game server for ranked play
- User accounts, ratings, game history
- Spectator mode

## New Files

```
src/network/
├── network_manager.gd      # Autoload: connection state machine
├── webrtc_client.gd        # WebRTC peer connection wrapper
├── signaling_client.gd     # WebSocket to signaling server
├── network_protocol.gd     # Message types and serialization
└── room_manager.gd         # Room create/join, codes

src/ui/multiplayer/
├── multiplayer_menu.tscn   # Create/Join game UI
├── multiplayer_menu.gd
├── room_lobby.tscn         # Pre-game lobby (color selection, ready)
└── room_lobby.gd

signaling-server/           # Separate deployment
├── index.js                # Node.js or Cloudflare Worker
└── package.json
```

## Key Implementation Details

### 1. Network Protocol Messages

```gdscript
enum MessageType {
    GAME_START,    # Host sends: {seed, settings, host_side}
    GAME_READY,    # Guest acknowledges
    MOVE,          # {from, to, seq}
    PLACEMENT,     # {column, seq}
    PROMOTION,     # {piece_type, seq}
    ACK,           # {seq}
    STATE_HASH,    # {hash, move_count} - periodic verification
    FULL_STATE,    # Full GameState.to_dict() for resync
    RESIGN,
    DRAW_OFFER,
    DRAW_ACCEPT,
    REMATCH,
    PING/PONG
}
```

### 2. RNG Synchronization

PieceArrivalManager uses RNG for piece sequences. Solution:
- Host generates seed at game start
- Both clients use same seed → identical piece sequences
- No need to sync individual pieces

```gdscript
# Host creates game
var seed := randi()
arrival_manager.initialize(mode, frequency, seed)
network.send({type: GAME_START, seed: seed, ...})

# Guest receives and uses same seed
arrival_manager.initialize(mode, frequency, received_seed)
```

### 3. Move Flow

**Local move:**
1. Validate locally via existing `try_move()`
2. Execute optimistically
3. Send to opponent: `{type: MOVE, from, to, seq}`
4. Await ACK

**Remote move:**
1. Receive message
2. Validate move is legal (security)
3. Execute via `try_move()`
4. Send ACK

### 4. State Verification

After each turn, exchange state hash:
```gdscript
var hash := JSON.stringify(game_state.to_dict()).hash()
network.send({type: STATE_HASH, hash: hash, move_count: n})
```

On mismatch: host sends full state, guest rebuilds.

### 5. Room Code System

- 6 characters: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no ambiguous 0/O/1/I)
- Host creates room → gets code → shares with friend
- Guest enters code → joins room → WebRTC handshake begins

### 6. Connection Flow

```
1. Host: Create Room → Get code "AB3XY7"
2. Guest: Enter code → Join Room
3. Signaling server connects them
4. WebRTC handshake via signaling server
5. P2P DataChannel established
6. Disconnect from signaling server
7. Game begins over P2P
```

## Signaling Server (Decision: Minimal Self-Hosted)

Deploy a ~50 line signaling server on **Cloudflare Workers** or **Railway** (free tier).

Only used for initial WebRTC handshake (~5 seconds), then P2P takes over.

```javascript
// Minimal signaling server (Node.js example)
const rooms = new Map();

wss.on('connection', (ws) => {
  ws.on('message', (msg) => {
    const {type, code, data} = JSON.parse(msg);
    if (type === 'create') {
      const roomCode = generateCode();
      rooms.set(roomCode, {host: ws});
      ws.send(JSON.stringify({type: 'created', code: roomCode}));
    } else if (type === 'join') {
      const room = rooms.get(code);
      if (room) {
        room.guest = ws;
        room.host.send(JSON.stringify({type: 'peer_joined'}));
        // Relay WebRTC signals between host and guest
      }
    } else if (type === 'signal') {
      // Relay to other peer
    }
  });
});
```

## Implementation Steps

### Step 1: Network Infrastructure
- [ ] Create `NetworkProtocol` (message types, encode/decode)
- [ ] Create `SignalingClient` (WebSocket connection)
- [ ] Create `WebRTCClient` (Godot WebRTC wrapper)
- [ ] Create `NetworkManager` autoload
- [ ] Deploy minimal signaling server

### Step 2: Room System
- [ ] Create `RoomManager` (create/join rooms)
- [ ] Create multiplayer menu UI
- [ ] Test WebRTC connection flow

### Step 3: Game Integration
- [ ] Extend game flow for network moves
- [ ] Add RNG seed exchange
- [ ] Implement remote move application
- [ ] Add turn validation for network

### Step 4: Robustness
- [ ] State hash verification
- [ ] Full state resync on mismatch
- [ ] Disconnect handling
- [ ] Reconnection attempt

### Step 5: Polish
- [ ] Resign/draw offer
- [ ] Rematch option
- [ ] Connection status indicator
- [ ] Error messages

## Critical Files to Modify

- `src/game/game_state.gd` - Add network hooks, expose state for sync
- `src/game/piece_arrival.gd` - Accept seed parameter for RNG
- `src/main.gd` - Add "Online" menu option
- `src/ui/board/board_view.gd` - Handle remote player's turn (disable input)
- `project.godot` - Register NetworkManager autoload

## Verification

1. **Unit tests**: Protocol encoding, room code validation
2. **Integration tests**: Two browser tabs, full game flow
3. **Cross-browser**: Chrome, Firefox, Safari
4. **Network conditions**: Test with simulated latency
5. **Edge cases**: Disconnect mid-move, simultaneous actions

## Decisions Made

1. **Signaling server**: Minimal self-hosted (Cloudflare Workers or Railway)
2. **Color selection**: Host chooses in lobby (White or Black)
3. **Time controls**: Support existing clock options (can be enabled in lobby)
