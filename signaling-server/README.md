# Saktris Signaling Server

Minimal WebSocket server for WebRTC signaling in Saktris online multiplayer.

## What It Does

- Creates game rooms with 6-character codes
- Relays WebRTC signaling messages between host and guest
- Automatically cleans up inactive rooms after 30 minutes

## Local Development

```bash
cd signaling-server
npm install
npm run dev
```

Server runs on `ws://localhost:8080`

## Deployment Options

### Railway (Recommended - Free Tier)

1. Create account at [railway.app](https://railway.app)
2. Connect GitHub repo
3. Select `signaling-server` directory
4. Railway auto-detects Node.js and deploys

### Render

1. Create account at [render.com](https://render.com)
2. Create new Web Service from GitHub
3. Set root directory to `signaling-server`
4. Set build command: `npm install`
5. Set start command: `npm start`

### Fly.io

```bash
cd signaling-server
fly launch
fly deploy
```

## After Deployment

Update the signaling server URL in the game:

```gdscript
# src/network/network_manager.gd
const SIGNALING_SERVER_URL := "wss://your-server-url.example.com"
```

## Protocol

### Client → Server

```json
{"type": "create"}              // Create room, returns {type: "created", code: "ABC123"}
{"type": "join", "code": "ABC123"}  // Join room
{"type": "leave"}               // Leave room
{"type": "signal", "signal_type": "offer|answer|ice", ...}  // WebRTC signal
```

### Server → Client

```json
{"type": "created", "code": "ABC123"}  // Room created
{"type": "joined", "code": "ABC123"}   // Joined room
{"type": "error", "message": "..."}    // Error
{"type": "peer_joined"}                // Opponent joined
{"type": "peer_left"}                  // Opponent left
{"type": "signal", ...}                // WebRTC signal from peer
```
