import React, { useState, createContext, useContext } from 'react';

// Translation dictionaries
const translations = {
  en: {
    // Header
    headerTitle: "🤖 AI Tech News Aggregator",
    headerSubtitle: "Real-time aggregation of the latest AI, ML, and deep learning news",
    totalArticles: "Total Articles:",
    totalSources: "Sources:",
    searchPlaceholder: "Search AI News...",
    searchButton: "Search",
    
    // Filters
    filterSources: "Filter Sources:",
    all: "All",
    
    // Article elements
    noRelatedNews: "No related news found",
    refreshData: "Refresh Data",
    
    // Footer
    footerText: "AI Tech News Aggregator - Get the latest AI updates in real-time",
    footerUpdateInfo: "Data updates every hour",
    
    // Loading
    loading: "Loading...",
    
    // Other
    copyright: "© 2026 AI Tech News Aggregator"
  },
  zh: {
    // Header
    headerTitle: "🤖 AI 科技新闻聚合",
    headerSubtitle: "实时聚合最新的人工智能、机器学习、深度学习等领域新闻",
    totalArticles: "总文章数:",
    totalSources: "数据源:",
    searchPlaceholder: "搜索AI新闻...",
    searchButton: "搜索",
    
    // Filters
    filterSources: "筛选来源:",
    all: "全部",
    
    // Article elements
    noRelatedNews: "没有找到相关新闻",
    refreshData: "刷新数据",
    
    // Footer
    footerText: "AI 科技新闻聚合 - 实时获取最新AI资讯",
    footerUpdateInfo: "数据每小时自动更新",
    
    // Loading
    loading: "加载中...",
    
    // Other
    copyright: "© 2026 AI 科技新闻聚合"
  }
};

// Create context for language management
const LanguageContext = createContext();

// Provider component
export const LanguageProvider = ({ children }) => {
  const [language, setLanguage] = useState('zh'); // Default to Chinese

  const toggleLanguage = () => {
    setLanguage(prevLang => prevLang === 'zh' ? 'en' : 'zh');
  };

  const t = (key) => {
    return translations[language][key] || key;
  };

  return (
    <LanguageContext.Provider value={{ language, toggleLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  );
};

// Hook to use language context
export const useLanguage = () => {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
};