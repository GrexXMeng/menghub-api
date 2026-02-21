// ============================================================
// MengHub Server Finder - Backend API
// Tech stack: Node.js + Express (gratis deploy di Render.com)
// ============================================================
// CARA DEPLOY:
// 1. Install Node.js
// 2. npm init -y && npm install express
// 3. node server.js
// Atau deploy gratis di https://render.com (pilih Web Service, paste kode ini)
// ============================================================

const express = require("express");
const app = express();
app.use(express.json());

// ⚙️ Konfigurasi — samakan dengan di script Lua kamu
const SECRET_KEY = "menghub_secret_2025"; // Ganti dengan secret key unikmu
const SERVER_TTL = 90 * 1000;              // Server dianggap expired setelah 90 detik

// In-memory store: { jobId: { ...serverData, lastSeen: timestamp } }
const serverStore = {};

// ============================================================
// HELPER: Hapus server yang sudah expired
// ============================================================
function cleanExpiredServers() {
    const now = Date.now();
    for (const jobId in serverStore) {
        if (now - serverStore[jobId].lastSeen > SERVER_TTL) {
            delete serverStore[jobId];
            console.log(`[EXPIRED] Removed server: ${jobId}`);
        }
    }
}

// Cleanup tiap 30 detik
setInterval(cleanExpiredServers, 30_000);

// ============================================================
// ROUTES
// ============================================================

// Health check
app.get("/", (req, res) => {
    res.json({
        status: "ok",
        service: "MengHub Server Finder API",
        activeServers: Object.keys(serverStore).length
    });
});

// POST /register — Script Lua mengirim data servernya
app.post("/register", (req, res) => {
    const { jobId, placeId, playerCount, maxPlayers, events, username, version, secret } = req.body;

    // Validasi secret
    if (secret !== SECRET_KEY) {
        return res.status(403).json({ error: "Unauthorized" });
    }

    // Validasi field wajib
    if (!jobId || !placeId) {
        return res.status(400).json({ error: "jobId dan placeId wajib diisi" });
    }

    // Simpan / update data server
    serverStore[jobId] = {
        jobId,
        placeId,
        playerCount: playerCount || 0,
        maxPlayers: maxPlayers || 20,
        events: Array.isArray(events) ? events : [],
        registeredBy: username || "Unknown",
        lastSeen: Date.now()
    };

    console.log(`[REGISTER] ${username} | Server: ${jobId} | Events: ${events?.join(", ") || "none"}`);
    res.json({ success: true, message: "Server registered" });
});

// POST /unregister — Script Lua unregister saat player leave
app.post("/unregister", (req, res) => {
    const { jobId, secret } = req.body;

    if (secret !== SECRET_KEY) {
        return res.status(403).json({ error: "Unauthorized" });
    }

    if (serverStore[jobId]) {
        delete serverStore[jobId];
        console.log(`[UNREGISTER] Server: ${jobId}`);
    }

    res.json({ success: true });
});

// GET /servers — Ambil daftar server (dengan optional filter)
app.get("/servers", (req, res) => {
    cleanExpiredServers();

    const { placeId, event } = req.query;

    let servers = Object.values(serverStore);

    // Filter berdasarkan placeId (wajib agar tidak campur dengan game lain)
    if (placeId) {
        servers = servers.filter(s => s.placeId === placeId);
    }

    // Filter berdasarkan event (opsional)
    if (event && event !== "All" && event !== "") {
        servers = servers.filter(s =>
            s.events.some(e => e.toLowerCase().includes(event.toLowerCase()))
        );
    }

    // Sort: server dengan paling banyak event di atas, lalu player count
    servers.sort((a, b) => {
        if (b.events.length !== a.events.length) return b.events.length - a.events.length;
        return a.playerCount - b.playerCount; // Server sepi lebih cocok untuk farm
    });

    res.json({
        success: true,
        count: servers.length,
        servers: servers.map(s => ({
            jobId: s.jobId,
            playerCount: s.playerCount,
            maxPlayers: s.maxPlayers,
            events: s.events,
            registeredBy: s.registeredBy
        }))
    });
});

// ============================================================
// START SERVER
// ============================================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`✅ MengHub Server Finder API running on port ${PORT}`);
});
