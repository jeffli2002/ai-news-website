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

# Initialize with sample data if storage is empty
if not news_storage:
    print("Initializing with sample articles...")
    from datetime import datetime
    sample_articles = [
        {
            'id': 1,
            'title': 'Breakthrough in Large Language Models: New Architecture Achieves Superior Performance',
            'summary': 'Researchers have developed a novel transformer architecture that significantly improves efficiency and reduces computational requirements while maintaining high performance.',
            'content': 'The new model architecture introduces several innovations including sparse attention mechanisms, dynamic routing, and improved parameter efficiency. Early tests show 40% reduction in computational requirements with equivalent performance to current state-of-the-art models.',
            'link': 'https://example-ai-news.com/new-architecture',
            'published': str(datetime.now()),
            'source': 'AI Research Today',
            'scraped_at': str(datetime.now())
        },
        {
            'id': 2,
            'title': 'OpenAI Releases Next Generation Multimodal AI System',
            'summary': 'The latest multimodal AI system can process and understand text, images, audio, and video simultaneously with unprecedented accuracy.',
            'content': 'This advancement represents a significant leap in artificial general intelligence, with applications spanning autonomous systems, content creation, and scientific research. The system demonstrates remarkable capabilities in cross-modal understanding and generation.',
            'link': 'https://example-ai-news.com/multimodal-ai',
            'published': str(datetime.now()),
            'source': 'AI Technology News',
            'scraped_at': str(datetime.now())
        },
        {
            'id': 3,
            'title': 'Machine Learning Model Achieves Human-Level Performance in Complex Reasoning Tasks',
            'summary': 'New benchmarks show that the latest models can perform complex logical reasoning, planning, and problem-solving at human expert levels.',
            'content': 'The model was tested across diverse domains including mathematics, science, law, and medicine, consistently achieving scores comparable to human experts. This breakthrough has implications for automation across many professional fields.',
            'link': 'https://example-ai-news.com/human-level-reasoning',
            'published': str(datetime.now()),
            'source': 'Deep Learning Daily',
            'scraped_at': str(datetime.now())
        }
    ]
    
    for article in sample_articles:
        news_storage.append(article)
    
    print(f"Initialized with {len(sample_articles)} sample articles")

# Run an immediate scrape on startup to populate with real data
print("Running initial news scrape on startup...")
scrape_all_feeds()
print(f"Initial scrape completed. Total articles: {len(news_storage)}")

if __name__ == '__main__':
    # Start the scheduler in a separate thread
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()
    
    # Run the Flask app
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)