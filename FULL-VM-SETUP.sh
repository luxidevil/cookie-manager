#!/bin/bash

# ==============================================================================
# \ud83c\udf6a COOKIE MANAGER - COMPLETE VM SETUP SCRIPT
# ==============================================================================
# 
# This script does EVERYTHING:
# 1. Installs Docker
# 2. Creates all configuration files
# 3. Embeds the actual application code
# 4. Builds and starts the app
#
# USAGE: Just copy this entire script to your GCP VM and run:
#   sudo bash FULL-VM-SETUP.sh
#
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                       ║"
echo "║       🍪  COOKIE MANAGER - COMPLETE VM SETUP                         ║"
echo "║                                                                       ║"
echo "║       This will install everything automatically!                     ║"
echo "║                                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: Please run with sudo${NC}"
    echo ""
    echo "Usage: sudo bash FULL-VM-SETUP.sh"
    exit 1
fi

APP_DIR="/opt/cookie-manager"

step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  STEP $1: $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

done_msg() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

# ==============================================================================
# STEP 1: SYSTEM UPDATE
# ==============================================================================
step "1/7" "Updating system packages"
apt-get update -qq
apt-get upgrade -y -qq
done_msg "System updated"

# ==============================================================================
# STEP 2: INSTALL DOCKER
# ==============================================================================
step "2/7" "Installing Docker"

if command -v docker &> /dev/null; then
    done_msg "Docker already installed"
else
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker
    done_msg "Docker installed and started"
fi

# ==============================================================================
# STEP 3: CREATE DIRECTORIES
# ==============================================================================
step "3/7" "Creating application directory"
mkdir -p $APP_DIR/{backend,frontend/src,frontend/public}
cd $APP_DIR
done_msg "Created $APP_DIR"

# ==============================================================================
# STEP 4: CREATE DOCKER & CONFIG FILES
# ==============================================================================
step "4/7" "Creating Docker configuration"

# Create Dockerfile
cat > Dockerfile << 'DOCKERFILE_EOF'
# Multi-stage Dockerfile for Cookie Manager

# Stage 1: Build Frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy package files
COPY frontend/package.json frontend/yarn.lock* ./

# Install dependencies
RUN yarn install --frozen-lockfile || yarn install

# Copy frontend source
COPY frontend/ ./

# Build the frontend
RUN yarn build

# Stage 2: Production Image
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements and install
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy backend code
COPY backend/ ./backend/

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/frontend/build ./frontend/build

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create log directory
RUN mkdir -p /var/log/supervisor

# Expose port
EXPOSE 8080

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
DOCKERFILE_EOF
done_msg "Created Dockerfile"

# Create nginx.conf
cat > nginx.conf << 'NGINX_EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 8080;
        server_name _;

        # Frontend static files
        location / {
            root /app/frontend/build;
            index index.html;
            try_files $uri $uri/ /index.html;
        }

        # Backend API proxy
        location /api {
            proxy_pass http://127.0.0.1:8001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
NGINX_EOF
done_msg "Created nginx.conf"

# Create supervisord.conf
cat > supervisord.conf << 'SUPERVISOR_EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:backend]
command=python -m uvicorn server:app --host 0.0.0.0 --port 8001
directory=/app/backend
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log
SUPERVISOR_EOF
done_msg "Created supervisord.conf"

# Create docker-compose.prod.yml
cat > docker-compose.prod.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "80:8080"
    environment:
      - MONGO_URL=mongodb://mongo:27017
      - DB_NAME=cookie_manager
      - CORS_ORIGINS=*
      - JWT_SECRET=${JWT_SECRET:-seko-cookie-secret-key-2024-production}
      - RDP_ENDPOINT_URL=${RDP_ENDPOINT_URL:-}
    depends_on:
      mongo:
        condition: service_healthy
    restart: always
    networks:
      - cookie-network

  mongo:
    image: mongo:6
    volumes:
      - mongo_data:/data/db
      - mongo_config:/data/configdb
    restart: always
    networks:
      - cookie-network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  mongo_data:
    driver: local
  mongo_config:
    driver: local

networks:
  cookie-network:
    driver: bridge
COMPOSE_EOF
done_msg "Created docker-compose.prod.yml"

# Create .env
cat > .env << 'ENV_EOF'
JWT_SECRET=seko-cookie-secret-key-2024-production
RDP_ENDPOINT_URL=
ENV_EOF
done_msg "Created .env"

# ==============================================================================
# STEP 5: CREATE BACKEND CODE
# ==============================================================================
step "5/7" "Creating backend application"

# Create requirements.txt
cat > backend/requirements.txt << 'REQ_EOF'
fastapi==0.110.1
uvicorn==0.25.0
motor==3.3.1
pymongo==4.5.0
python-dotenv==1.2.1
PyJWT==2.11.0
httpx==0.28.1
pydantic==2.12.5
starlette==0.37.2
REQ_EOF
done_msg "Created requirements.txt"

# Create server.py
cat > backend/server.py << 'SERVER_EOF'
from fastapi import FastAPI, APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
import json
import re
import httpx
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
import uuid
from datetime import datetime, timezone
import jwt

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ.get('MONGO_URL', 'mongodb://localhost:27017')
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ.get('DB_NAME', 'cookie_manager')]

# JWT Config
JWT_SECRET = os.environ.get('JWT_SECRET', 'seko-cookie-secret-key-2024')
JWT_ALGORITHM = "HS256"

# RDP Config
RDP_ENDPOINT_URL = os.environ.get('RDP_ENDPOINT_URL', '')

# Create the main app
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

security = HTTPBearer()

# Models
class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    token: str
    username: str

class CookieCreate(BaseModel):
    content: str

class CookieResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    content: str
    name: str
    sold: bool = False
    expired: bool = False
    link_generated: bool = False
    created_at: str

class CookieUpdate(BaseModel):
    sold: Optional[bool] = None
    expired: Optional[bool] = None
    link_generated: Optional[bool] = None

class GenerateLinkRequest(BaseModel):
    cookie_id: str

class GenerateLinkResponse(BaseModel):
    link: str

class ValidationResult(BaseModel):
    valid: bool
    message: str
    formatted_content: Optional[str] = None

# Auth helper
def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

# Cookie validation helper
def validate_and_format_cookie(content: str) -> dict:
    cleaned = content.strip()
    if cleaned.startswith('\ufeff'):
        cleaned = cleaned[1:]
    cleaned = cleaned.replace('"', '"').replace('"', '"')
    cleaned = cleaned.replace(''', "'").replace(''', "'")
    cleaned = cleaned.replace('\t', ' ')
    cleaned = cleaned.replace('\r\n', '\n').replace('\r', '\n')
    
    parse_attempts = [
        lambda c: json.loads(c),
        lambda c: json.loads('\n'.join(line.strip() for line in c.split('\n'))),
        lambda c: json.loads(re.sub(r'(\w+)(?=\s*:)', r'"\1"', c)),
        lambda c: json.loads('[' + c + ']') if not c.strip().startswith('[') and c.count('{') > 1 else None,
    ]
    
    last_error = None
    for attempt in parse_attempts:
        try:
            result = attempt(cleaned)
            if result is not None:
                formatted = json.dumps(result, indent=2)
                return {"valid": True, "message": "Cookie JSON is valid", "formatted_content": formatted, "parsed": result}
        except (json.JSONDecodeError, Exception) as e:
            last_error = str(e)
            continue
    
    return {"valid": False, "message": f"Invalid JSON format: {last_error}", "formatted_content": None, "parsed": None}

# Auth endpoints
@api_router.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    if request.username == "seko" and request.password == "SEKO1234":
        token = jwt.encode(
            {"username": request.username, "exp": datetime.now(timezone.utc).timestamp() + 86400},
            JWT_SECRET, algorithm=JWT_ALGORITHM
        )
        return LoginResponse(token=token, username=request.username)
    raise HTTPException(status_code=401, detail="Invalid credentials")

@api_router.get("/auth/verify")
async def verify_auth(user: dict = Depends(verify_token)):
    return {"valid": True, "username": user.get("username")}

# Cookie endpoints
@api_router.post("/cookies/validate", response_model=ValidationResult)
async def validate_cookie(request: CookieCreate, user: dict = Depends(verify_token)):
    result = validate_and_format_cookie(request.content)
    return ValidationResult(valid=result["valid"], message=result["message"], formatted_content=result["formatted_content"])

@api_router.post("/cookies", response_model=CookieResponse)
async def create_cookie(request: CookieCreate, user: dict = Depends(verify_token)):
    result = validate_and_format_cookie(request.content)
    if not result["valid"]:
        raise HTTPException(status_code=400, detail=result["message"])
    count = await db.cookies.count_documents({})
    cookie_id = str(uuid.uuid4())
    cookie_doc = {
        "id": cookie_id, "content": result["formatted_content"], "name": f"Cookie {count + 1}",
        "sold": False, "expired": False, "link_generated": False, "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.cookies.insert_one(cookie_doc)
    return CookieResponse(**{k: v for k, v in cookie_doc.items() if k != "_id"})

@api_router.get("/cookies", response_model=List[CookieResponse])
async def get_cookies(user: dict = Depends(verify_token)):
    cookies = await db.cookies.find({}, {"_id": 0}).sort("created_at", -1).to_list(1000)
    return [CookieResponse(**c) for c in cookies]

@api_router.get("/cookies/{cookie_id}", response_model=CookieResponse)
async def get_cookie(cookie_id: str, user: dict = Depends(verify_token)):
    cookie = await db.cookies.find_one({"id": cookie_id}, {"_id": 0})
    if not cookie:
        raise HTTPException(status_code=404, detail="Cookie not found")
    return CookieResponse(**cookie)

@api_router.patch("/cookies/{cookie_id}", response_model=CookieResponse)
async def update_cookie(cookie_id: str, update: CookieUpdate, user: dict = Depends(verify_token)):
    update_dict = {k: v for k, v in update.model_dump().items() if v is not None}
    if not update_dict:
        raise HTTPException(status_code=400, detail="No updates provided")
    result = await db.cookies.find_one_and_update({"id": cookie_id}, {"$set": update_dict}, return_document=True, projection={"_id": 0})
    if not result:
        raise HTTPException(status_code=404, detail="Cookie not found")
    return CookieResponse(**result)

@api_router.delete("/cookies/{cookie_id}")
async def delete_cookie(cookie_id: str, user: dict = Depends(verify_token)):
    result = await db.cookies.delete_one({"id": cookie_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Cookie not found")
    return {"message": "Cookie deleted"}

@api_router.post("/cookies/{cookie_id}/generate-link", response_model=GenerateLinkResponse)
async def generate_link(cookie_id: str, user: dict = Depends(verify_token)):
    cookie = await db.cookies.find_one({"id": cookie_id}, {"_id": 0})
    if not cookie:
        raise HTTPException(status_code=404, detail="Cookie not found")
    if not RDP_ENDPOINT_URL:
        raise HTTPException(status_code=503, detail="RDP endpoint not configured")
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(RDP_ENDPOINT_URL, content=cookie["content"], headers={"Content-Type": "application/json"})
            response.raise_for_status()
            link = response.text.strip()
            await db.cookies.update_one({"id": cookie_id}, {"$set": {"link_generated": True, "generated_link": link}})
            return GenerateLinkResponse(link=link)
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="RDP request timed out")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"RDP error: {e.response.status_code}")
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Failed to connect to RDP: {str(e)}")

@api_router.get("/health")
async def health_check():
    return {"status": "healthy"}

app.include_router(api_router)

app.add_middleware(
    CORSMiddleware, allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"], allow_headers=["*"],
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
SERVER_EOF
done_msg "Created server.py"

echo ""
echo -e "${YELLOW}⚠️  Note: Frontend files are too large to embed in this script.${NC}"
echo -e "${YELLOW}   You need to copy the frontend/ folder separately.${NC}"
echo ""
echo "Options:"
echo "  1. Copy frontend folder from your local machine"
echo "  2. Or download from your repository"
echo ""

# ==============================================================================
# STEP 6: CREATE SYSTEMD SERVICE
# ==============================================================================
step "6/7" "Creating auto-start service"

cat > /etc/systemd/system/cookie-manager.service << SVCEOF
[Unit]
Description=Cookie Manager Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d --build
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.prod.yml up -d --build
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable cookie-manager.service
done_msg "Systemd service created and enabled"

# ==============================================================================
# STEP 7: FINAL MESSAGE
# ==============================================================================
step "7/7" "Setup complete!"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                       ║${NC}"
echo -e "${GREEN}║              ✅  SETUP COMPLETE!                                      ║${NC}"
echo -e "${GREEN}║                                                                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: You still need to copy the frontend/ folder!${NC}"
echo ""
echo "From your local machine, run:"
echo -e "  ${CYAN}scp -r frontend/ YOUR_USERNAME@YOUR_VM_IP:/opt/cookie-manager/${NC}"
echo ""
echo "Then start the application:"
echo -e "  ${CYAN}cd /opt/cookie-manager${NC}"
echo -e "  ${CYAN}sudo docker compose -f docker-compose.prod.yml up -d --build${NC}"
echo ""
echo "Or use systemd:"
echo -e "  ${CYAN}sudo systemctl start cookie-manager${NC}"
echo ""
echo "Your app will be available at:"
echo -e "  ${CYAN}http://YOUR_VM_EXTERNAL_IP${NC}"
echo ""
echo "Login credentials:"
echo "  Username: seko"
echo "  Password: SEKO1234"
echo ""
