# 🍪 Cookie Manager

A simple web application for managing browser cookies with validation, storage, and organization features.

## Features

- 🔐 Secure login authentication
- 📋 Cookie paste with smart JSON validation (fixes common formatting issues)
- 📦 Cookie storage with MongoDB
- ✅ Mark cookies as sold/expired
- 🔗 Generate links (optional RDP integration)
- 📱 Clean, responsive UI

## Quick Start

### For GCP VM Deployment (Recommended)

👉 **See [DEPLOY-README.md](DEPLOY-README.md)** for step-by-step instructions.

### For Local Development

```bash
# Using Docker Compose
docker-compose up --build

# Access at http://localhost:8080
```

### Default Login

- **Username:** `seko`
- **Password:** `SEKO1234`

## Project Structure

```
├── backend/          # FastAPI Python backend
│   ├── server.py     # Main API server
│   └── requirements.txt
├── frontend/         # React frontend
│   ├── src/
│   └── package.json
├── Dockerfile        # Multi-stage Docker build
├── docker-compose.prod.yml  # Production compose
├── nginx.conf        # Nginx configuration
└── supervisord.conf  # Process manager config
```

## Deployment Options

| Option | Cost | Best For |
|--------|------|----------|
| GCP VM (e2-medium) | ~$25/mo | 24/7 operation, full control |
| GCP Cloud Run | Pay per use | Variable traffic |
| Local Docker | Free | Development/testing |

## Documentation

- [DEPLOY-README.md](DEPLOY-README.md) - Simple deployment guide for beginners
- [VM-DEPLOYMENT-GUIDE.md](VM-DEPLOYMENT-GUIDE.md) - Detailed VM deployment guide
- [README-DEPLOYMENT.md](README-DEPLOYMENT.md) - Cloud Run deployment (original)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGO_URL` | MongoDB connection string | `mongodb://mongo:27017` |
| `DB_NAME` | Database name | `cookie_manager` |
| `JWT_SECRET` | Secret for JWT tokens | (set in production!) |
| `RDP_ENDPOINT_URL` | Optional RDP service URL | (empty) |

## License

Private - Internal Use Only
