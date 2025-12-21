// server.js - Node.js + Express + WebSocket Server for Collaborative Editing
const express = require("express");
const http = require("http");
const WebSocket = require("ws");
const { v4: uuidv4 } = require("uuid");

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Middleware
app.use(express.json());
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(200);
  next();
});

// ===================================================
// In-Memory Storage
// ===================================================

// Documents list (just metadata)
const documents = [];

// Document updates storage: docId -> array of updates (as base64 strings)
const documentUpdates = new Map();

// Active WebSocket connections: docId -> Set of WebSocket clients
const documentConnections = new Map();

// ===================================================
// REST API Endpoints
// ===================================================

// GET /documents - List all documents
app.get("/documents", (req, res) => {
  res.json(documents);
});

// POST /documents - Create a new document
app.post("/documents", (req, res) => {
  const { name } = req.body;
  const doc = {
    id: uuidv4(),
    name: name || "Untitled",
    createdAt: new Date().toISOString(),
  };
  documents.push(doc);

  // Initialize empty updates array for this document
  documentUpdates.set(doc.id, []);

  console.log(`📄 Created document: ${doc.name} (${doc.id})`);
  res.status(201).json(doc);
});

// DELETE /documents/:id - Delete a document
app.delete("/documents/:id", (req, res) => {
  const { id } = req.params;
  const index = documents.findIndex((d) => d.id === id);

  if (index === -1) {
    return res.status(404).json({ error: "Document not found" });
  }

  const doc = documents[index];
  documents.splice(index, 1);

  // Clean up updates and connections
  documentUpdates.delete(id);

  // Close all WebSocket connections for this document
  const connections = documentConnections.get(id);
  if (connections) {
    connections.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.close(1000, "Document deleted");
      }
    });
    documentConnections.delete(id);
  }

  console.log(`🗑️  Deleted document: ${doc.name} (${id})`);
  res.sendStatus(204);
});

// ===================================================
// WebSocket Handling
// ===================================================

wss.on("connection", (ws, req) => {
  // Extract docId from URL: /sync/:docId
  const match = req.url.match(/^\/sync\/([^/]+)$/);
  if (!match) {
    console.log("❌ Invalid WebSocket URL");
    ws.close(1003, "Invalid URL");
    return;
  }

  const docId = match[1];
  console.log(`🔌 Client connected to document: ${docId}`);

  // Initialize updates array if it doesn't exist
  if (!documentUpdates.has(docId)) {
    documentUpdates.set(docId, []);
  }

  // Add this connection to the document's connection set
  if (!documentConnections.has(docId)) {
    documentConnections.set(docId, new Set());
  }
  documentConnections.get(docId).add(ws);

  // Store docId on the WebSocket for later cleanup
  ws.docId = docId;

  // Handle incoming messages
  ws.on("message", (data) => {
    try {
      const message = JSON.parse(data);

      if (message.type === "initialRequest") {
        // Send all existing updates to this client
        const updates = documentUpdates.get(docId) || [];
        ws.send(JSON.stringify(updates));
        console.log(
          `📤 Sent ${updates.length} initial updates to client for doc ${docId}`
        );
      } else if (message.type === "update") {
        // Store the update
        const update = message.data; // Array of numbers (Uint8List converted)
        documentUpdates.get(docId).push(update);

        console.log(
          `💾 Stored update for doc ${docId} (${update.length} bytes)`
        );

        // Broadcast to all other clients connected to this document
        const connections = documentConnections.get(docId);
        connections.forEach((client) => {
          if (client !== ws && client.readyState === WebSocket.OPEN) {
            // Send as array of updates (client expects this format)
            client.send(JSON.stringify([update]));
          }
        });

        console.log(
          `📡 Broadcast update to ${connections.size - 1} other clients`
        );
      }
    } catch (err) {
      console.error("❌ Error processing message:", err);
    }
  });

  // Handle disconnection
  ws.on("close", () => {
    console.log(`🔌 Client disconnected from document: ${docId}`);
    const connections = documentConnections.get(docId);
    if (connections) {
      connections.delete(ws);
      if (connections.size === 0) {
        documentConnections.delete(docId);
        console.log(`📭 No more clients for document: ${docId}`);
      }
    }
  });

  ws.on("error", (err) => {
    console.error("❌ WebSocket error:", err);
  });
});

// ===================================================
// Health Check
// ===================================================

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    documents: documents.length,
    activeConnections: Array.from(documentConnections.entries()).map(
      ([docId, connections]) => ({
        docId,
        clients: connections.size,
        updates: documentUpdates.get(docId)?.length || 0,
      })
    ),
  });
});

// ===================================================
// Start Server
// ===================================================

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════╗
║   🚀 Collaborative Editor Server Running          ║
╠═══════════════════════════════════════════════════╣
║   REST API:    http://localhost:${PORT}            ║
║   WebSocket:   ws://localhost:${PORT}/sync/:docId  ║
║   Health:      http://localhost:${PORT}/health     ║
╚═══════════════════════════════════════════════════╝
  `);
  console.log(`📄 Initial documents: ${documents.length}`);
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("📛 SIGTERM received, closing server...");
  server.close(() => {
    console.log("✅ Server closed");
    process.exit(0);
  });
});
