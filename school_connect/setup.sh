#!/bin/bash

echo "🎓 School Connect - Frappe/ERPNext Setup"
echo "========================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Starting Docker containers...${NC}"
docker-compose down 2>/dev/null
docker-compose up -d

echo -e "${YELLOW}Step 2: Waiting for MariaDB to be ready...${NC}"
sleep 10

# Check if MariaDB is ready
for i in {1..30}; do
    if docker exec school_connect_db mysqladmin ping -h localhost -u root -padmin > /dev/null 2>&1; then
        echo -e "${GREEN}MariaDB is ready!${NC}"
        break
    fi
    echo "Waiting for MariaDB... ($i/30)"
    sleep 2
done

echo -e "${YELLOW}Step 3: Creating Frappe site...${NC}"
docker exec school_connect_backend bench new-site site1.localhost \
    --mariadb-root-password admin \
    --admin-password admin \
    --force

echo -e "${YELLOW}Step 4: Installing ERPNext...${NC}"
docker exec school_connect_backend bench --site site1.localhost install-app erpnext

echo -e "${YELLOW}Step 5: Copying School Connect app...${NC}"
# Copy the app files into the container
docker cp ./school_connect school_connect_backend:/home/frappe/frappe-bench/apps/

echo -e "${YELLOW}Step 6: Installing School Connect app...${NC}"
docker exec school_connect_backend bench --site site1.localhost install-app school_connect

echo -e "${YELLOW}Step 7: Setting developer mode...${NC}"
docker exec school_connect_backend bench --site site1.localhost set-config developer_mode 1

echo -e "${YELLOW}Step 8: Migrating database...${NC}"
docker exec school_connect_backend bench --site site1.localhost migrate

echo -e "${YELLOW}Step 9: Restarting bench...${NC}"
docker restart school_connect_backend

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Access your Frappe/ERPNext instance:"
echo -e "  ${GREEN}http://localhost:8000${NC}"
echo ""
echo "Login credentials:"
echo -e "  Email: ${GREEN}Administrator${NC}"
echo -e "  Password: ${GREEN}admin${NC}"
echo ""
echo "To view logs:"
echo "  docker logs -f school_connect_backend"
echo ""
echo "To stop the environment:"
echo "  docker-compose down"
