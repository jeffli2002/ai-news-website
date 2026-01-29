# Vercel serverless function entry point
from api.news import app

def handler(event, context):
    return app(event, context)
