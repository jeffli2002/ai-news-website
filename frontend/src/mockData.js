export const mockArticles = [
  {
    id: 1,
    title: "OpenAI发布GPT-4 Turbo：更快、更便宜、更强大",
    content: "OpenAI在其首届开发者大会上发布了GPT-4 Turbo，这是GPT-4的升级版本。",
    summary: "OpenAI发布GPT-4 Turbo，具有更长上下文、更低价格和最新知识库",
    link: "https://openai.com/blog",
    source: "OpenAI Blog",
    published: new Date().toISOString()
  },
  {
    id: 2,
    title: "谷歌推出Gemini：多模态AI模型",
    content: "谷歌DeepMind推出了其最新的多模态AI模型Gemini。",
    summary: "谷歌发布多模态AI模型Gemini",
    link: "https://deepmind.google/technologies/gemini/",
    source: "Google DeepMind",
    published: new Date(Date.now() - 3600000).toISOString()
  },
  {
    id: 3,
    title: "Meta发布Llama 3：开源大语言模型",
    content: "Meta发布了Llama 3系列模型，包括8B和70B参数版本。",
    summary: "Meta开源Llama 3大语言模型",
    link: "https://ai.meta.com/blog/",
    source: "Meta AI",
    published: new Date(Date.now() - 7200000).toISOString()
  }
];

export const mockSources = ["OpenAI Blog", "Google DeepMind", "Meta AI"];
export const mockStats = { total_articles: 3, total_sources: 3 };
