"""
RDP Link Generation Service
This service receives cookies from the Cookie Manager and returns generated links.
Runs on port 5000 on the same VM.

To run: python server.py
"""

from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse
import uvicorn
import json
import uuid

app = FastAPI()

@app.post("/generate-link")
async def generate_link(request: Request):
    """
    Receives raw cookie JSON and returns an HTTPS link.
    
    The cookie JSON is sent as raw body (not JSON-wrapped).
    Returns plain text HTTPS link.
    """
    # Get the raw cookie JSON from request body
    cookie_data = await request.body()
    cookie_json = cookie_data.decode('utf-8')
    
    print(f"Received cookie: {cookie_json[:100]}...")  # Log first 100 chars
    
    # ============================================
    # YOUR LOGIC HERE
    # Process the cookie and generate your link
    # ============================================
    
    # For now, generate a placeholder link
    # Replace this with your actual link generation logic
    link_id = str(uuid.uuid4())[:8]
    generated_link = f"https://your-domain.com/link/{link_id}"
    
    # ============================================
    
    print(f"Generated link: {generated_link}")
    
    # Return the link as plain text
    return PlainTextResponse(generated_link)


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    print("Starting RDP Link Generation Service on port 5000...")
    print("Waiting to receive cookies from Cookie Manager...")
    uvicorn.run(app, host="0.0.0.0", port=5000)
