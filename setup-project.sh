#!/bin/bash

# setup-project.sh
# Script to initialize the AI News Website project

set -e  # Exit on any error

echo "🏗️ Setting up AI News Website project..."

# Create directory structure
echo "📂 Creating directory structure..."
mkdir -p ai-news-website/{backend,frontend/src,frontend/public,.github/workflows}

# Initialize git repository
cd ai-news-website
git init

# Create .gitignore
cat > .gitignore << 'GITIGNORE_EOF'
# Dependencies
node_modules/
__pycache__/
*.pyc
.venv/
venv/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Production builds
build/
dist/
*.min.js

# IDE
.vscode/
.idea/

# Vercel
.vercel/
GITIGNORE_EOF

# Create README
cat > README.md << 'README_EOF'
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
README_EOF

# Create backend files
mkdir -p backend
cat > backend/app.py << 'BACKEND_EOF'
from flask import Flask, jsonify, request
from flask_cors import CORS
import feedparser
import requests
from datetime import datetime, timedelta
import threading
import time
import schedule
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# In-memory storage for news articles
news_storage = []

# RSS feeds for AI news sources
RSS_FEEDS = [
    'https://www.artificialintelligence-news.com/feed/',
    'https://ai.googleblog.com/feeds/posts/default',
    'https://openai.com/blog/rss.xml',
    'https://www.deepmind.com/rss',
    'https://ai.meta.com/feed/',
    'https://syncedreview.com/feed/',
    'https://www.wired.com/feed/category/ai/latest/rss'
]

def fetch_article_content(url):
    """Fetch article content from URL"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(url, headers=headers, timeout=10)
        return response.text[:500] + "..."  # First 500 chars as preview
    except:
        return ""

def scrape_rss_feed(feed_url):
    """Scrape a single RSS feed"""
    try:
        feed = feedparser.parse(feed_url)
        articles = []
        
        for entry in feed.entries[:10]:  # Limit to 10 most recent
            # Check if article already exists
            existing = next((a for a in news_storage if a['link'] == entry.link), None)
            if existing:
                continue
                
            article = {
                'id': hash(entry.link),  # Simple ID generation
                'title': entry.title,
                'summary': entry.summary if hasattr(entry, 'summary') else '',
                'content': fetch_article_content(entry.link) if len(news_storage) < 50 else '',  # Limit content fetches
                'link': entry.link,
                'published': entry.published if hasattr(entry, 'published') else str(datetime.now()),
                'source': feed.feed.title if hasattr(feed, 'feed') and hasattr(feed.feed, 'title') else 'Unknown Source',
                'scraped_at': str(datetime.now())
            }
            articles.append(article)
        
        return articles
    except Exception as e:
        print(f"Error scraping {feed_url}: {str(e)}")
        return []

def scrape_all_feeds():
    """Scrape all RSS feeds"""
    print("Starting news scraping...")
    all_articles = []
    
    for feed_url in RSS_FEEDS:
        articles = scrape_rss_feed(feed_url)
        all_articles.extend(articles)
        print(f"Scraped {len(articles)} articles from {feed_url}")
    
    # Update storage with new articles
    for article in all_articles:
        # Check if article already exists
        existing_index = next((i for i, a in enumerate(news_storage) if a['id'] == article['id']), None)
        if existing_index is not None:
            # Update existing article
            news_storage[existing_index] = article
        else:
            # Add new article
            news_storage.append(article)
    
    # Keep only the 100 most recent articles
    news_storage.sort(key=lambda x: x['published'], reverse=True)
    del news_storage[100:]
    
    print(f"Updated news storage with {len(all_articles)} new articles. Total: {len(news_storage)} articles.")

def run_scheduler():
    """Run the scheduler in a separate thread"""
    def job():
        scrape_all_feeds()
    
    # Schedule the job to run every hour
    schedule.every().hour.do(job)
    
    # Run the initial job
    job()
    
    while True:
        schedule.run_pending()
        time.sleep(60)  # Check every minute

@app.route('/api/news', methods=['GET'])
def get_news():
    """Get all news articles"""
    sort_by = request.args.get('sort', 'published')  # Default sort by published date
    order = request.args.get('order', 'desc')  # Default order descending
    
    # Sort the news
    sorted_news = sorted(news_storage, key=lambda x: x[sort_by], reverse=(order == 'desc'))
    
    # Pagination
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 20))
    start_idx = (page - 1) * per_page
    end_idx = start_idx + per_page
    
    paginated_news = sorted_news[start_idx:end_idx]
    
    return jsonify({
        'articles': paginated_news,
        'total': len(sorted_news),
        'page': page,
        'per_page': per_page,
        'total_pages': (len(sorted_news) + per_page - 1) // per_page
    })

@app.route('/api/news/search', methods=['GET'])
def search_news():
    """Search news articles by keyword"""
    query = request.args.get('q', '')
    if not query:
        return jsonify({'articles': [], 'total': 0})
    
    filtered_articles = [
        article for article in news_storage 
        if query.lower() in article['title'].lower() or query.lower() in article['summary'].lower()
    ]
    
    return jsonify({
        'articles': filtered_articles,
        'total': len(filtered_articles)
    })

@app.route('/api/sources', methods=['GET'])
def get_sources():
    """Get list of sources"""
    sources = list(set(article['source'] for article in news_storage))
    return jsonify({'sources': sources})

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get statistics about the news"""
    total_articles = len(news_storage)
    sources = list(set(article['source'] for article in news_storage))
    
    return jsonify({
        'total_articles': total_articles,
        'total_sources': len(sources),
        'sources': sources
    })

if __name__ == '__main__':
    # Start the scheduler in a separate thread
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()
    
    # Run the Flask app
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
BACKEND_EOF

cat > backend/requirements.txt << 'REQ_EOF'
Flask==2.3.3
feedparser==6.0.10
requests==2.31.0
schedule==1.2.0
flask-cors==4.0.0
gunicorn==21.2.0
REQ_EOF

# Create frontend files
cat > frontend/package.json << 'PKG_EOF'
{
  "name": "ai-news-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^5.17.0",
    "@testing-library/react": "^13.4.0",
    "@testing-library/user-event": "^13.5.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.6.0",
    "moment": "^2.29.4",
    "web-vitals": "^2.1.4"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "devDependencies": {
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.31",
    "tailwindcss": "^3.3.5"
  }
}
PKG_EOF

cat > frontend/src/index.js << 'IDX_EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
IDX_EOF

cat > frontend/src/App.js << 'APP_EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import moment from 'moment';
import 'moment/locale/zh-cn';
import './App.css';

function App() {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedSource, setSelectedSource] = useState('');
  const [sources, setSources] = useState([]);
  const [stats, setStats] = useState({});

  const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api';

  useEffect(() => {
    fetchData();
    fetchSources();
    fetchStats();
    
    // Refresh data every 10 minutes
    const interval = setInterval(fetchData, 600000);
    return () => clearInterval(interval);
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_BASE_URL}/news?per_page=50`);
      setArticles(response.data.articles);
    } catch (error) {
      console.error('Error fetching news:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchSources = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/sources`);
      setSources(response.data.sources);
    } catch (error) {
      console.error('Error fetching sources:', error);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/stats`);
      setStats(response.data);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  const handleSearch = async (e) => {
    e.preventDefault();
    if (!searchTerm.trim()) {
      fetchData();
      return;
    }

    try {
      setLoading(true);
      const response = await axios.get(`${API_BASE_URL}/news/search?q=${encodeURIComponent(searchTerm)}`);
      setArticles(response.data.articles);
    } catch (error) {
      console.error('Error searching news:', error);
    } finally {
      setLoading(false);
    }
  };

  const filterBySource = (source) => {
    if (!source) {
      fetchData();
      return;
    }

    const filtered = articles.filter(article => article.source === source);
    setArticles(filtered);
  };

  const formatDate = (dateString) => {
    moment.locale('zh-cn');
    return moment(dateString).fromNow();
  };

  return (
    <div className="App">
      <header className="bg-gradient-to-r from-blue-600 to-indigo-700 text-white py-6 px-4 shadow-lg">
        <div className="container mx-auto">
          <h1 className="text-3xl md:text-4xl font-bold mb-2">🤖 AI 科技新闻聚合</h1>
          <p className="text-blue-100">实时聚合最新的人工智能、机器学习、深度学习等领域新闻</p>
          
          <div className="mt-4 flex flex-col sm:flex-row gap-4 justify-between items-center">
            <div className="flex flex-wrap gap-2">
              <div className="bg-blue-500 bg-opacity-50 px-3 py-1 rounded-full text-sm">
                总文章数: {stats.total_articles || 0}
              </div>
              <div className="bg-indigo-500 bg-opacity-50 px-3 py-1 rounded-full text-sm">
                数据源: {stats.total_sources || 0}个
              </div>
            </div>
            
            <form onSubmit={handleSearch} className="flex flex-grow max-w-md">
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="搜索AI新闻..."
                className="flex-grow px-4 py-2 rounded-l-lg text-gray-800 focus:outline-none"
              />
              <button 
                type="submit"
                className="bg-yellow-500 hover:bg-yellow-600 text-black px-4 py-2 rounded-r-lg font-medium transition-colors"
              >
                搜索
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="container mx-auto py-6 px-4">
        <div className="mb-6">
          <h2 className="text-xl font-semibold mb-3">筛选来源:</h2>
          <div className="flex flex-wrap gap-2">
            <button 
              onClick={() => filterBySource('')}
              className={`px-3 py-1 rounded-full text-sm ${!selectedSource ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-800 hover:bg-gray-300'}`}
            >
              全部
            </button>
            {sources.slice(0, 10).map((source, index) => (
              <button
                key={index}
                onClick={() => {
                  setSelectedSource(source);
                  filterBySource(source);
                }}
                className={`px-3 py-1 rounded-full text-sm truncate max-w-[200px] ${
                  selectedSource === source 
                    ? 'bg-blue-600 text-white' 
                    : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
                }`}
                title={source}
              >
                {source}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {articles.map((article) => (
              <div key={article.id} className="bg-white rounded-xl shadow-md overflow-hidden hover:shadow-xl transition-shadow duration-300">
                <div className="p-5">
                  <div className="flex justify-between items-start mb-2">
                    <h3 className="text-lg font-semibold text-gray-800 mb-2 line-clamp-2">
                      <a 
                        href={article.link} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="hover:text-blue-600 transition-colors"
                      >
                        {article.title}
                      </a>
                    </h3>
                  </div>
                  
                  <p className="text-gray-600 text-sm mb-4 line-clamp-3">
                    {article.summary || article.content}
                  </p>
                  
                  <div className="flex flex-wrap justify-between items-center text-xs text-gray-500">
                    <span className="bg-gray-100 px-2 py-1 rounded">
                      {article.source}
                    </span>
                    <span title={new Date(article.published).toLocaleString()}>
                      {formatDate(article.published)}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {articles.length === 0 && !loading && (
          <div className="text-center py-12">
            <div className="text-gray-500 text-lg">没有找到相关新闻</div>
            <button 
              onClick={fetchData}
              className="mt-4 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors"
            >
              刷新数据
            </button>
          </div>
        )}
      </div>

      <footer className="bg-gray-800 text-white py-6 mt-12">
        <div className="container mx-auto px-4 text-center">
          <p>© {new Date().getFullYear()} AI 科技新闻聚合 - 实时获取最新AI资讯</p>
          <p className="text-gray-400 text-sm mt-2">数据每小时自动更新</p>
        </div>
      </footer>
    </div>
  );
}

export default App;
APP_EOF

cat > frontend/src/index.css << 'CSS_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: #f5f7fa;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.line-clamp-3 {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
CSS_EOF

cat > frontend/tailwind.config.js << 'TAILWIND_EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
TAILWIND_EOF

# Create Vercel configuration
cat > vercel.json << 'VERCEL_EOF'
{
  "version": 2,
  "name": "ai-news-website",
  "builds": [
    {
      "src": "backend/app.py",
      "use": "@vercel/python",
      "config": { "runtime": "python3.9" }
    },
    {
      "src": "frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build"
      }
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "backend/app.py"
    },
    {
      "src": "/(.*)",
      "dest": "frontend/$1",
      "headers": {
        "cache-control": "public, max-age=31536000"
      }
    }
  ]
}
VERCEL_EOF

# Create GitHub Actions workflow
mkdir -p .github/workflows
cat > .github/workflows/deploy.yml << 'WORKFLOW_EOF'
name: Deploy to Vercel

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: 'frontend/package-lock.json'

    - name: Install frontend dependencies
      run: |
        cd frontend
        npm ci

    - name: Build frontend
      run: |
        cd frontend
        npm run build

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'

    - name: Install Python dependencies
      run: |
        cd backend
        pip install -r requirements.txt

    - name: Deploy to Vercel
      run: |
        # Install Vercel CLI
        npm install -g vercel@latest
        
        # Pull Vercel environment information
        vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}
        
        # Build the project files
        vercel build --prod --token=${{ secrets.VERCEL_TOKEN }}
        
        # Deploy the output to Vercel
        vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
      env:
        VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
        VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}

    - name: Verify deployment
      run: |
        echo "Application deployed successfully!"
        echo "Check your deployment at: https://${{ secrets.VERCEL_PROJECT_NAME }}.vercel.app"
WORKFLOW_EOF

# Create deployment script
cat > deploy-to-vercel.sh << 'DEPLOY_EOF'
#!/bin/bash

# deploy-to-vercel.sh
# Script to automate deployment of AI News Website to Vercel

set -e  # Exit on any error

echo "🚀 Starting deployment of AI News Website to Vercel..."

# Check if vercel is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI not found. Installing..."
    npm install -g vercel@latest
fi

# Navigate to project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "📁 Project directory: $PROJECT_DIR"

# Check if frontend has been built
if [ ! -d "frontend/build" ]; then
    echo "📦 Building frontend..."
    cd frontend
    npm install
    npm run build
    cd ..
fi

# Check if backend dependencies are installed
if [ ! -f "backend/requirements.txt" ]; then
    echo "❌ Backend requirements.txt not found!"
    exit 1
fi

echo "🔍 Checking for Vercel configuration..."

# Check if vercel.json exists
if [ ! -f "vercel.json" ]; then
    echo "❌ vercel.json not found! Please create a vercel.json file first."
    exit 1
fi

echo "✅ Configuration looks good!"

# Check if we're logged into Vercel
if ! vercel whoami &> /dev/null; then
    echo "🔐 You are not logged in to Vercel. Please log in:"
    echo "   vercel login"
    echo "   Or set up your Vercel token as an environment variable."
    exit 1
fi

# Deploy to Vercel
echo " ↑ Deploying to Vercel..."
vercel --confirm --prod

echo "🎉 Deployment completed successfully!"
echo "🌐 Your application is now live at: $(vercel --scope $(vercel whoami) url)"

echo ""
echo "📋 Next steps:"
echo "- Visit your deployed application"
echo "- Configure custom domain if needed"
echo "- Set up environment variables if required"
echo "- Monitor your application performance"
DEPLOY_EOF

chmod +x deploy-to-vercel.sh

# Initialize frontend
cd frontend
npm init -y
npm install react react-dom
npm install @testing-library/jest-dom @testing-library/react @testing-library/user-event
npm install axios moment
npm install tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Create basic public index.html
mkdir -p public
cat > public/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta
      name="description"
      content="AI News Aggregator - Get the latest AI, ML, and DL news in one place"
    />
    <title>AI News Aggregator</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
HTML_EOF

cd ..

echo "✅ Project setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Review the code and customize as needed"
echo "2. Set up your Vercel account and project"
echo "3. Add your Vercel tokens to GitHub Secrets (VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID)"
echo "4. Push your code to GitHub to trigger automatic deployment"
echo ""
echo "💻 To run locally:"
echo "   # Backend: cd backend && python -m flask run"
echo "   # Frontend: cd frontend && npm start"