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
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

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
    """Validate and try to fix cookie JSON format"""
    # Remove common Excel/copy-paste artifacts
    cleaned = content.strip()
    
    # Try to detect and fix common issues
    # Remove BOM
    if cleaned.startswith('\ufeff'):
        cleaned = cleaned[1:]
    
    # Replace smart quotes with regular quotes
    cleaned = cleaned.replace('"', '"').replace('"', '"')
    cleaned = cleaned.replace(''', "'").replace(''', "'")
    
    # Replace tabs with spaces
    cleaned = cleaned.replace('\t', ' ')
    
    # Remove carriage returns
    cleaned = cleaned.replace('\r\n', '\n').replace('\r', '\n')
    
    # Try multiple parsing strategies
    parse_attempts = [
        # Attempt 1: Direct parse
        lambda c: json.loads(c),
        # Attempt 2: Remove leading/trailing whitespace per line
        lambda c: json.loads('\n'.join(line.strip() for line in c.split('\n'))),
        # Attempt 3: Try to fix unquoted keys
        lambda c: json.loads(re.sub(r'(\w+)(?=\s*:)', r'"\1"', c)),
        # Attempt 4: Wrap in array if it looks like multiple objects
        lambda c: json.loads('[' + c + ']') if not c.strip().startswith('[') and c.count('{') > 1 else None,
    ]
    
    last_error = None
    for attempt in parse_attempts:
        try:
            result = attempt(cleaned)
            if result is not None:
                # Successfully parsed, format it nicely
                formatted = json.dumps(result, indent=2)
                return {
                    "valid": True,
                    "message": "Cookie JSON is valid",
                    "formatted_content": formatted,
                    "parsed": result
                }
        except (json.JSONDecodeError, Exception) as e:
            last_error = str(e)
            continue
    
    return {
        "valid": False,
        "message": f"Invalid JSON format: {last_error}",
        "formatted_content": None,
        "parsed": None
    }

# Auth endpoints
@api_router.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    # Hardcoded credentials as per requirement
    if request.username == "seko" and request.password == "SEKO1234":
        token = jwt.encode(
            {
                "username": request.username,
                "exp": datetime.now(timezone.utc).timestamp() + 86400  # 24 hours
            },
            JWT_SECRET,
            algorithm=JWT_ALGORITHM
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
    return ValidationResult(
        valid=result["valid"],
        message=result["message"],
        formatted_content=result["formatted_content"]
    )

@api_router.post("/cookies", response_model=CookieResponse)
async def create_cookie(request: CookieCreate, user: dict = Depends(verify_token)):
    # Validate first
    result = validate_and_format_cookie(request.content)
    if not result["valid"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    # Count existing cookies for naming
    count = await db.cookies.count_documents({})
    
    cookie_id = str(uuid.uuid4())
    cookie_doc = {
        "id": cookie_id,
        "content": result["formatted_content"],
        "name": f"Cookie {count + 1}",
        "sold": False,
        "expired": False,
        "link_generated": False,
        "created_at": datetime.now(timezone.utc).isoformat()
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
    
    result = await db.cookies.find_one_and_update(
        {"id": cookie_id},
        {"$set": update_dict},
        return_document=True,
        projection={"_id": 0}
    )
    
    if not result:
        raise HTTPException(status_code=404, detail="Cookie not found")
    
    return CookieResponse(**result)

@api_router.delete("/cookies/{cookie_id}")
async def delete_cookie(cookie_id: str, user: dict = Depends(verify_token)):
    result = await db.cookies.delete_one({"id": cookie_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Cookie not found")
    return {"message": "Cookie deleted"}

# Health check
@api_router.get("/health")
async def health_check():
    return {"status": "healthy"}

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
