#!/usr/bin/env bash
# ============================================================
# SchoolConnect — Server Setup & Deploy Script
#
# Run this ON YOUR AWS LIGHTSAIL SERVER to:
#   1. Upgrade Node.js to 22+ (via NodeSource)
#   2. Install/update PM2 globally
#   3. Build both frontend apps
#   4. Start all services via PM2
#   5. Configure PM2 to survive reboots
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo -e "${GREEN}=== SchoolConnect Deploy ===${NC}"
echo "Project dir: $PROJECT_DIR"
echo ""

# ── Step 1: Check current Node version ──────────────────────────────
echo -e "${YELLOW}Step 1: Checking Node.js version...${NC}"
CURRENT_NODE=$(node -v 2>/dev/null || echo "not installed")
echo "Current Node: $CURRENT_NODE"

# Extract major version number
NODE_MAJOR=$(echo "$CURRENT_NODE" | sed 's/v\([0-9]*\).*/\1/')
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ] 2>/dev/null; then
    echo -e "${YELLOW}Node.js 22+ required. Installing via NodeSource...${NC}"
    
    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    
    # Setup NodeSource repo for Node 22
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
    
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    
    sudo apt-get update
    sudo apt-get install -y nodejs
    
    echo -e "${GREEN}Node.js installed: $(node -v)${NC}"
else
    echo -e "${GREEN}Node.js version OK: $CURRENT_NODE${NC}"
fi

# ── Step 2: Install/update PM2 ─────────────────────────────────────
echo ""
echo -e "${YELLOW}Step 2: Installing/updating PM2...${NC}"
sudo npm install -g pm2
echo -e "${GREEN}PM2 version: $(pm2 -v)${NC}"

# ── Step 3: Install dependencies ────────────────────────────────────
echo ""
echo -e "${YELLOW}Step 3: Installing dependencies...${NC}"
npm install
cd schooladmin && npm install && cd ..
cd superadmin && npm install && cd ..
cd sc_backend && npm install && cd ..
cd "$PROJECT_DIR"

# ── Step 4: Build both frontends ───────────────────────────────────
echo ""
echo -e "${YELLOW}Step 4: Building frontends...${NC}"

cd schooladmin
echo "Building schooladmin..."
npx vite build --mode live
cd "$PROJECT_DIR"

cd superadmin
echo "Building superadmin..."
npx vite build --mode live
cd "$PROJECT_DIR"

echo -e "${GREEN}Frontend builds complete.${NC}"

# ── Step 5: Stop old PM2 processes ─────────────────────────────────
echo ""
echo -e "${YELLOW}Step 5: Stopping old PM2 processes...${NC}"
pm2 delete sc_backend 2>/dev/null || true
pm2 delete server 2>/dev/null || true
pm2 delete schooladmin 2>/dev/null || true
pm2 delete superadmin 2>/dev/null || true

# ── Step 6: Start all services ─────────────────────────────────────
echo ""
echo -e "${YELLOW}Step 6: Starting all services via PM2...${NC}"
pm2 start ecosystem.config.cjs

# ── Step 7: Persist across reboots ──────────────────────────────────
echo ""
echo -e "${YELLOW}Step 7: Configuring PM2 startup on boot...${NC}"
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu 2>/dev/null || {
    echo -e "${YELLOW}If pm2 startup failed, run this manually:${NC}"
    echo "  sudo env PATH=\$PATH:\$(dirname \$(which node)) pm2 startup systemd -u ubuntu --hp /home/ubuntu"
    echo "  pm2 save"
}

# ── Step 8: Verify ─────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Step 8: Verifying services...${NC}"
sleep 3

echo ""
pm2 list
echo ""

# Check backend health
if curl -sSf --max-time 5 http://localhost:5173/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ sc_backend (schooladmin + API :5173) — healthy${NC}"
else
    echo -e "${RED}❌ sc_backend (schooladmin + API :5173) — not responding${NC}"
fi

if curl -sSf --max-time 5 http://localhost:5175/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ sc_backend (superadmin + API :5175) — healthy${NC}"
else
    echo -e "${RED}❌ sc_backend (superadmin + API :5175) — not responding${NC}"
fi

echo ""
echo -e "${GREEN}=== Deploy Complete ===${NC}"
echo "School Admin UI/API: http://13.205.212.64:5173"
echo "Super Admin UI/API:  http://13.205.212.64:5175"
echo ""
echo "Useful commands:"
echo "  pm2 list              — see all services"
echo "  pm2 logs              — tail all logs"
echo "  pm2 logs sc_backend   — backend logs only"
echo "  pm2 restart all       — restart everything"
echo "  pm2 monit             — real-time monitoring"
