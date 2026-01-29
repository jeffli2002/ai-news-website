import React, { useState, useEffect } from 'react';
import axios from 'axios';
import moment from 'moment';
import { mockArticles, mockSources, mockStats } from './mockData';
import { useLanguage, LanguageProvider } from './i18n';
import 'moment/locale/zh-cn';
import 'moment/locale/en-gb';
import './App.css';

// Clean source names for better display
const cleanSourceName = (source) => {
  const mapping = {
    'openai news': 'OpenAI',
    'ai news': 'AI News',
    'synced': 'Synced Review',
    'google ai blog': 'Google AI',
    'deepmind': 'DeepMind',
    'meta ai': 'Meta AI'
  };
  return mapping[source.toLowerCase()] || source;
};

function App() {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedSource, setSelectedSource] = useState('');
  const [sources, setSources] = useState([]);
  const [stats, setStats] = useState({});
  
  const { t, language, toggleLanguage } = useLanguage();

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
      // Only set mock data if we're not in production
      if (process.env.NODE_ENV !== 'production') {
        setArticles(mockArticles);
      }
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
      setSources(mockSources);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/stats`);
      setStats(response.data);
    } catch (error) {
      console.error('Error fetching stats:', error);
      setStats(mockStats);
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
    moment.locale(language === 'zh' ? 'zh-cn' : 'en');
    return moment(dateString).fromNow();
  };

  return (
    <div className="App">
      <header className="bg-gradient-to-r from-blue-600 to-indigo-700 text-white py-6 px-4 shadow-lg">
        <div className="container mx-auto">
          <div className="flex justify-between items-center mb-4">
            <h1 className="text-3xl md:text-4xl font-bold">{t('headerTitle')}</h1>
            <button
              onClick={toggleLanguage}
              className="bg-white text-blue-600 px-3 py-1 rounded-lg font-medium hover:bg-gray-100 transition-colors"
            >
              {language === 'zh' ? 'EN' : '中文'}
            </button>
          </div>
          <p className="text-blue-100">{t('headerSubtitle')}</p>
          
          <div className="mt-4 flex flex-col sm:flex-row gap-4 justify-between items-center">
            <div className="flex flex-wrap gap-2">
              <div className="bg-blue-500 bg-opacity-50 px-3 py-1 rounded-full text-sm">
                {t('totalArticles')} {stats.total_articles || 0}
              </div>
              <div className="bg-indigo-500 bg-opacity-50 px-3 py-1 rounded-full text-sm">
                {t('totalSources')} {stats.total_sources || 0}
              </div>
            </div>
            
            <form onSubmit={handleSearch} className="flex flex-grow max-w-md">
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder={t('searchPlaceholder')}
                className="flex-grow px-4 py-2 rounded-l-lg text-gray-800 focus:outline-none"
              />
              <button 
                type="submit"
                className="bg-yellow-500 hover:bg-yellow-600 text-black px-4 py-2 rounded-r-lg font-medium transition-colors"
              >
                {t('searchButton')}
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="container mx-auto py-6 px-4">
        <div className="mb-6">
          <h2 className="text-xl font-semibold mb-3">{t('filterSources')}</h2>
          <div className="flex flex-wrap gap-2">
            <button 
              onClick={() => filterBySource('')}
              className={`px-3 py-1 rounded-full text-sm ${!selectedSource ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-800 hover:bg-gray-300'}`}
            >
              {t('all')}
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
                {cleanSourceName(source)}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
          </div>
        ) : (
          <div className="space-y-4">
            {articles.map((article) => (
              <div key={article.id} className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow duration-200">
                <div className="flex flex-col md:flex-row md:justify-between md:items-start gap-2">
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-gray-800 mb-1">
                      <a 
                        href={article.link} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="hover:text-blue-600 transition-colors"
                      >
                        {article.title}
                      </a>
                    </h3>
                    <p className="text-gray-600 text-sm mb-2 line-clamp-2">
                      {article.summary || article.content}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2 text-xs">
                    <span className="bg-blue-100 text-blue-800 px-2 py-1 rounded">
                      {cleanSourceName(article.source)}
                    </span>
                    <span className="bg-gray-100 text-gray-600 px-2 py-1 rounded" title={new Date(article.published).toLocaleString()}>
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
            <div className="text-gray-500 text-lg">{t('noRelatedNews')}</div>
            <button 
              onClick={fetchData}
              className="mt-4 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors"
            >
              {t('refreshData')}
            </button>
          </div>
        )}
      </div>

      <footer className="bg-gray-800 text-white py-6 mt-12">
        <div className="container mx-auto px-4 text-center">
          <p>{t('copyright')} - {t('footerText')}</p>
          <p className="text-gray-400 text-sm mt-2">{t('footerUpdateInfo')}</p>
        </div>
      </footer>
    </div>
  );
}

export default App;