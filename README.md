# AI News Aggregator

A modern AI news aggregation platform that pulls the latest AI-related articles from various sources and presents them in a clean, responsive interface.

## Features

- Real-time AI news aggregation from multiple sources
- Responsive React frontend with search and filtering
- Python Flask backend with scheduled scraping
- Automatic deployment via GitHub Actions
- Deployed on Vercel for optimal performance

## Architecture

```
Frontend (React) ↔ Backend (Flask) ↔ Data Storage ↔ RSS Feed Sources
```

## Tech Stack

- Frontend: React, TypeScript, Tailwind CSS
- Backend: Python, Flask, Requests, Feedparser
- Deployment: Vercel
- CI/CD: GitHub Actions
- Data: In-memory storage (can be extended with database)