#!/usr/bin/env bash
# =============================================================================
# app.sh — Bootstrap script for App Tier VM
# Installs Node.js 20 LTS and runs a simple Express API on port 8080
# =============================================================================
set -euo pipefail

echo "=== [app.sh] Starting App Tier bootstrap ==="

# ---- System update ----
apt-get update -y
apt-get upgrade -y

# ---- Install curl & gnupg (NodeSource prerequisite) ----
apt-get install -y curl gnupg ca-certificates

# ---- Add NodeSource repo and install Node.js 20 LTS ----
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ---- Verify installation ----
node --version
npm --version

# ---- Create app directory ----
APP_DIR="/opt/app"
mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

# ---- Write package.json ----
cat > package.json <<'PKG'
{
  "name": "app-tier",
  "version": "1.0.0",
  "description": "Azure 3-Tier — App Tier backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2",
    "mssql":   "^10.0.4"
  }
}
PKG

# ---- Install dependencies (Express + mssql) ----
npm install --omit=dev

# ---- Write Express API server (Azure SQL-connected) ----
cat > server.js <<'JS'
'use strict';

const express = require('express');
const sql     = require('mssql');

const app  = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());

// ── Azure SQL configuration ── populate /opt/app/.env from Terraform outputs ──
const sqlConfig = {
  server:   process.env.DB_SERVER || '',
  database: process.env.DB_NAME   || 'app-db',
  user:     process.env.DB_USER   || '',
  password: process.env.DB_PASS   || '',
  options: {
    encrypt:                true,
    trustServerCertificate: false,
    enableArithAbort:       true,
  },
  pool: {
    max:               5,
    min:               0,
    idleTimeoutMillis: 30000,
  },
  connectTimeout: 10000,
};

let pool = null;

async function getPool() {
  if (pool) return pool;
  if (!sqlConfig.server) throw new Error('DB_SERVER not configured in /opt/app/.env');
  pool = await sql.connect(sqlConfig);
  return pool;
}

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', tier: 'app', timestamp: new Date().toISOString() });
});

// ── Database connectivity status ──────────────────────────────────────────────
app.get('/db-status', async (_req, res) => {
  try {
    const p      = await getPool();
    const result = await p.request()
      .query('SELECT @@VERSION AS version, GETUTCDATE() AS server_time, DB_NAME() AS db_name');
    const row = result.recordset[0];
    res.json({
      connected:   true,
      db_name:     row.db_name,
      server_name: sqlConfig.server,
      server_time: row.server_time,
      sql_version: row.version.split('\n')[0],
    });
  } catch (err) {
    pool = null; // reset so next call retries
    res.status(503).json({ connected: false, error: err.message });
  }
});

// ── List tables ───────────────────────────────────────────────────────────────
app.get('/db/tables', async (_req, res) => {
  try {
    const p      = await getPool();
    const result = await p.request().query(
      "SELECT TABLE_NAME, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME"
    );
    res.json({ tables: result.recordset });
  } catch (err) {
    res.status(503).json({ error: err.message, tables: [] });
  }
});

// ── Initialise schema + seed data (idempotent) ───────────────────────────────
app.post('/db/setup', async (_req, res) => {
  try {
    const p = await getPool();
    await p.request().query(`
      IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'items')
        CREATE TABLE items (
          id         INT IDENTITY(1,1) PRIMARY KEY,
          name       NVARCHAR(100) NOT NULL,
          status     NVARCHAR(50)  NOT NULL DEFAULT 'active',
          created_at DATETIME2     NOT NULL DEFAULT GETUTCDATE()
        );
      IF NOT EXISTS (SELECT 1 FROM items)
        INSERT INTO items (name, status) VALUES
          ('Azure VM',      'active'),
          ('Load Balancer', 'active'),
          ('Key Vault',     'active'),
          ('Azure Bastion', 'active'),
          ('Azure Monitor', 'active');
    `);
    res.json({ success: true, message: 'Schema initialised and data seeded' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Items — queries DB with static fallback if DB is unavailable ──────────────
app.get('/items', async (_req, res) => {
  try {
    const p      = await getPool();
    const result = await p.request()
      .query('SELECT id, name, status, created_at FROM items ORDER BY id');
    res.json(result.recordset);
  } catch (_err) {
    res.json([
      { id: 1, name: 'Item A', status: 'active',   created_at: null },
      { id: 2, name: 'Item B', status: 'active',   created_at: null },
      { id: 3, name: 'Item C', status: 'inactive', created_at: null },
    ]);
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`App Tier listening on port ${PORT}`);
});
JS

# ---- Create systemd service ----
cat > /etc/systemd/system/app-tier.service <<UNIT
[Unit]
Description=Azure 3-Tier App Tier Service
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/node ${APP_DIR}/server.js
Restart=on-failure
RestartSec=5
EnvironmentFile=-/opt/app/.env
Environment=PORT=8080
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

# ---- Create .env template (populate from Terraform outputs / Key Vault after deploy) ----
if [ ! -f /opt/app/.env ]; then
  cat > /opt/app/.env <<'ENV'
DB_SERVER=
DB_NAME=app-db
DB_USER=sqladmin
DB_PASS=
PORT=8080
ENV
  chmod 600 /opt/app/.env
  chown nobody /opt/app/.env
fi

# ---- Enable & start service ----
systemctl daemon-reload
systemctl enable app-tier
systemctl start app-tier

echo "=== [app.sh] App Tier bootstrap complete ==="
