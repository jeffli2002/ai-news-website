from flask import Flask, jsonify, request
import feedparser
import requests
from datetime import datetime
import json
import os

app = Flask(__name__)

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

def scrape_rss_feed(feed_url):
    try:
        feed = feedparser.parse(feed_url)
        articles = []
        
        for entry in feed.entries[:5]:
            article = {
                'id': hash(entry.link),
                'title': entry.get('title', 'No title'),
                'summary': entry.get('summary', entry.get('description', ''))[:300],
                'content': entry.get('content', [{'value': ''}])[0].get('value', '')[:500] if 'content' in entry else entry.get('summary', '')[:500],
                'link': entry.link,
                'source': feed.feed.get('title', feed_url),
                'published': entry.get('published', datetime.now().isoformat())
            }
            articles.append(article)
        
        return articles
    except Exception as e:
        print(f"Error scraping {feed_url}: {str(e)}")
        return []

def fetch_all_news():
    all_articles = []
    for feed_url in RSS_FEEDS:
        articles = scrape_rss_feed(feed_url)
        all_articles.extend(articles)
    
    # Sort by published date (newest first)
    all_articles.sort(key=lambda x: x['published'], reverse=True)
    return all_articles

@app.route('/api/news', methods=['GET'])
def get_news():
    try:
        articles = fetch_all_news()
        per_page = int(request.args.get('per_page', 50))
        return jsonify({
            'articles': articles[:per_page],
            'total': len(articles)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/sources', methods=['GET'])
def get_sources():
    try:
        articles = fetch_all_news()
        sources = list(set([a['source'] for a in articles]))
        return jsonify({'sources': sources})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats', methods=['GET'])
def get_stats():
    try:
        articles = fetch_all_news()
        sources = list(set([a['source'] for a in articles]))
        return jsonify({
            'total_articles': len(articles),
            'total_sources': len(sources)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/news/search', methods=['GET'])
def search_news():
    try:
        query = request.args.get('q', '').lower()
        if not query:
            return get_news()
        
        articles = fetch_all_news()
        filtered = [
            a for a in articles 
            if query in a['title'].lower() or query in a.get('summary', '').lower()
        ]
        
        return jsonify({
            'articles': filtered,
            'total': len(filtered)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Vercel serverless function handler
def handler(request):
    with app.request_context(request.environ):
        return app.full_dispatch_request()
