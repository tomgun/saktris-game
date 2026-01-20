/**
 * Saktris Signaling Server
 *
 * Minimal WebSocket server for WebRTC signaling.
 * Handles room creation, joining, and signal relay between peers.
 *
 * Deploy to Railway, Render, Fly.io, or any Node.js hosting.
 *
 * Environment variables:
 * - PORT: Server port (default: 8080)
 */

const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8080;
const ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const ROOM_CODE_LENGTH = 6;
const ROOM_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes

// In-memory room storage
// In production, consider using Redis for multi-instance support
const rooms = new Map();

function generateRoomCode() {
  let code = "";
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    code += ROOM_CODE_CHARS[Math.floor(Math.random() * ROOM_CODE_CHARS.length)];
  }
  // Ensure unique
  if (rooms.has(code)) {
    return generateRoomCode();
  }
  return code;
}

function cleanupRoom(code) {
  const room = rooms.get(code);
  if (room) {
    clearTimeout(room.timeout);
    rooms.delete(code);
    console.log(`Room ${code} cleaned up`);
  }
}

function sendJson(ws, data) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

const wss = new WebSocketServer({ port: PORT });

console.log(`Saktris Signaling Server running on port ${PORT}`);

wss.on("connection", (ws) => {
  console.log("Client connected");

  let clientRoom = null;
  let isHost = false;

  ws.on("message", (message) => {
    let data;
    try {
      data = JSON.parse(message.toString());
    } catch (e) {
      console.error("Invalid JSON received");
      return;
    }

    const { type, code, signal_type, sdp, candidate } = data;

    switch (type) {
      case "create": {
        // Create a new room
        const roomCode = generateRoomCode();
        const room = {
          code: roomCode,
          host: ws,
          guest: null,
          timeout: setTimeout(() => cleanupRoom(roomCode), ROOM_TIMEOUT_MS),
        };
        rooms.set(roomCode, room);

        clientRoom = roomCode;
        isHost = true;

        sendJson(ws, { type: "created", code: roomCode });
        console.log(`Room ${roomCode} created`);
        break;
      }

      case "join": {
        // Join an existing room
        const joinCode = code?.toUpperCase();
        const room = rooms.get(joinCode);

        if (!room) {
          sendJson(ws, { type: "error", message: "Room not found" });
          break;
        }

        if (room.guest) {
          sendJson(ws, { type: "error", message: "Room is full" });
          break;
        }

        room.guest = ws;
        clientRoom = joinCode;
        isHost = false;

        // Notify guest they joined
        sendJson(ws, { type: "joined", code: joinCode });

        // Notify host that guest joined
        sendJson(room.host, { type: "peer_joined" });

        console.log(`Client joined room ${joinCode}`);
        break;
      }

      case "leave": {
        // Leave current room
        if (clientRoom) {
          const room = rooms.get(clientRoom);
          if (room) {
            if (isHost) {
              // Host leaving - notify guest and close room
              if (room.guest) {
                sendJson(room.guest, { type: "peer_left" });
              }
              cleanupRoom(clientRoom);
            } else {
              // Guest leaving - notify host
              room.guest = null;
              sendJson(room.host, { type: "peer_left" });
            }
          }
          clientRoom = null;
        }
        break;
      }

      case "signal": {
        // Relay WebRTC signaling to peer
        if (!clientRoom) {
          sendJson(ws, { type: "error", message: "Not in a room" });
          break;
        }

        const room = rooms.get(clientRoom);
        if (!room) break;

        // Determine target peer
        const target = isHost ? room.guest : room.host;
        if (!target) {
          sendJson(ws, { type: "error", message: "Peer not connected" });
          break;
        }

        // Forward the signal
        const signalData = {
          type: "signal",
          signal_type,
        };

        if (sdp) signalData.sdp = sdp;
        if (candidate) signalData.candidate = candidate;

        sendJson(target, signalData);
        break;
      }

      default:
        console.log(`Unknown message type: ${type}`);
    }
  });

  ws.on("close", () => {
    console.log("Client disconnected");

    if (clientRoom) {
      const room = rooms.get(clientRoom);
      if (room) {
        if (isHost) {
          // Host disconnected - notify guest and close room
          if (room.guest) {
            sendJson(room.guest, { type: "peer_left" });
          }
          cleanupRoom(clientRoom);
        } else {
          // Guest disconnected - notify host
          room.guest = null;
          if (room.host) {
            sendJson(room.host, { type: "peer_left" });
          }
        }
      }
    }
  });

  ws.on("error", (error) => {
    console.error("WebSocket error:", error);
  });
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("Shutting down...");
  wss.close(() => {
    process.exit(0);
  });
});
