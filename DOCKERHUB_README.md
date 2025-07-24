# Postcode Tracker App

A Flask-based application for tracking postcodes with PostgreSQL database.

## Quick Start

### Using Docker Compose (Recommended)

1. Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: your_db_user
      POSTGRES_PASSWORD: your_secure_password
      POSTGRES_DB: your_database_name
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U your_db_user -d your_database_name"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: YOUR_DOCKERHUB_USERNAME/postcode-tracker-app:latest
    restart: unless-stopped
    ports:
      - "8005:8005"
    environment:
      DB_USER: your_db_user
      DB_PASSWORD: your_secure_password
      DB_HOST: db
      DB_NAME: your_database_name
      DATABASE_URL: postgresql://your_db_user:your_secure_password@db/your_database_name
      FLASK_ENV: production
      SECRET_KEY: your-secret-key-here
      JWT_SECRET_KEY: your-jwt-secret-key-here
      WEB_CONCURRENCY: 4
    depends_on:
      db:
        condition: service_healthy

volumes:
  postgres_data:
```

2. Run the application:
```bash
docker-compose up -d
```

### Using Docker Run

```bash
# First, create a network
docker network create postcode-network

# Run PostgreSQL
docker run -d \
  --name postcode-db \
  --network postcode-network \
  -e POSTGRES_USER=your_db_user \
  -e POSTGRES_PASSWORD=your_secure_password \
  -e POSTGRES_DB=your_database_name \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15-alpine

# Run the application
docker run -d \
  --name postcode-app \
  --network postcode-network \
  -p 8005:8005 \
  -e DB_USER=your_db_user \
  -e DB_PASSWORD=your_secure_password \
  -e DB_HOST=postcode-db \
  -e DB_NAME=your_database_name \
  -e DATABASE_URL=postgresql://your_db_user:your_secure_password@postcode-db/your_database_name \
  -e FLASK_ENV=production \
  -e SECRET_KEY=your-secret-key-here \
  -e JWT_SECRET_KEY=your-jwt-secret-key-here \
  YOUR_DOCKERHUB_USERNAME/postcode-tracker-app:latest
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DB_USER` | PostgreSQL username | Yes |
| `DB_PASSWORD` | PostgreSQL password | Yes |
| `DB_HOST` | Database host (use `db` for docker-compose) | Yes |
| `DB_NAME` | Database name | Yes |
| `DATABASE_URL` | Full PostgreSQL connection URL | Yes |
| `FLASK_ENV` | Flask environment (production/development) | Yes |
| `SECRET_KEY` | Flask secret key for sessions | Yes |
| `JWT_SECRET_KEY` | JWT secret key for authentication | Yes |
| `WEB_CONCURRENCY` | Number of Gunicorn workers | No (default: 4) |

## Health Check

The application includes a health check endpoint at `/LocationApp/api/health`.

## Ports

- Application runs on port `8005`
- PostgreSQL runs on port `5432` (when using docker-compose)

## Source Code

The source code for this application is available at: [Your GitHub Repository URL]