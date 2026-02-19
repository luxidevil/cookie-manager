# Cookie Manager - Docker & GCP Deployment Guide

## Local Docker Development

### Prerequisites
- Docker and Docker Compose installed
- (Optional) MongoDB Compass for database inspection

### Quick Start

```bash
# Clone the repository
cd /app

# Start with Docker Compose
docker-compose up --build

# Access the app at http://localhost:8080
```

### Default Credentials
- Username: `seko`
- Password: `SEKO1234`

## GCP Cloud Run Deployment

### Prerequisites
1. Google Cloud account with billing enabled
2. `gcloud` CLI installed and configured
3. MongoDB Atlas account (for production database)

### Setup Steps

#### 1. Create MongoDB Atlas Cluster
1. Go to [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Create a free cluster
3. Create database user and get connection string
4. Whitelist all IPs (0.0.0.0/0) for Cloud Run

#### 2. Enable GCP Services

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required services
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

#### 3. Deploy via Cloud Build

```bash
# Deploy with environment variables
gcloud builds submit --config cloudbuild.yaml \
  --substitutions=_REGION=us-central1,_MONGO_URL="mongodb+srv://user:pass@cluster.mongodb.net",_JWT_SECRET="your-secure-secret"
```

#### Alternative: Manual Deployment

```bash
# Build the image
docker build -t gcr.io/YOUR_PROJECT_ID/cookie-manager .

# Push to Container Registry
docker push gcr.io/YOUR_PROJECT_ID/cookie-manager

# Deploy to Cloud Run
gcloud run deploy cookie-manager \
  --image gcr.io/YOUR_PROJECT_ID/cookie-manager \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars MONGO_URL="your-mongo-url",DB_NAME=cookie_manager,JWT_SECRET="your-secret" \
  --port 8080
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `MONGO_URL` | MongoDB connection string | Yes |
| `DB_NAME` | Database name (default: cookie_manager) | No |
| `JWT_SECRET` | Secret key for JWT tokens | Yes (in production) |
| `CORS_ORIGINS` | Allowed CORS origins | No |

## Architecture

```
┌─────────────────────────────────────────┐
│              Cloud Run                   │
│  ┌─────────────────────────────────────┐│
│  │            Nginx (:8080)            ││
│  │  ┌─────────────┬─────────────────┐ ││
│  │  │   /api      │    /            │ ││
│  │  │   Proxy     │    Static       │ ││
│  │  └──────┬──────┴─────────────────┘ ││
│  │         │                           ││
│  │  ┌──────▼──────┐  ┌──────────────┐ ││
│  │  │  FastAPI    │  │  React Build │ ││
│  │  │  (:8001)    │  │  (Static)    │ ││
│  │  └──────┬──────┘  └──────────────┘ ││
│  └─────────┼───────────────────────────┘│
└────────────┼────────────────────────────┘
             │
    ┌────────▼────────┐
    │  MongoDB Atlas  │
    └─────────────────┘
```

## Security Notes

1. In production, set a strong `JWT_SECRET`
2. Configure proper CORS origins
3. Use MongoDB Atlas IP whitelisting where possible
4. Enable Cloud Run authentication if needed
