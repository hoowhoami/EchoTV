export interface SiteConfig {
  key: string;
  name: string;
  api: string;
  detail?: string;
  disabled?: boolean;
  from?: 'config' | 'custom';
}

export interface LiveSource {
  key: string;
  name: string;
  url: string;
  ua?: string;
  epg?: string;
  logo?: string;
  channelNumber?: number;
  disabled?: boolean;
  from?: 'config' | 'custom';
}

export interface CustomCategory {
  name?: string;
  type: 'movie' | 'tv';
  query: string;
  disabled?: boolean;
  from?: 'config' | 'custom';
}

export interface AppConfig {
  api_site?: { [key: string]: { name: string, api: string, detail?: string } };
  lives?: { [key: string]: { name: string, url: string, ua?: string, epg?: string } };
  custom_category?: CustomCategory[];
  cache_time?: number;
  // UI 状态使用的展开格式
  sites: SiteConfig[];
  live_configs: LiveSource[];
  categories: CustomCategory[];
  // 站点配置
  site_name?: string;
  announcement?: string;
  proxy_type?: string;
  proxy_url?: string;
}

export interface DoubanSubject {
  id: string;
  title: string;
  rate: string;
  cover: string;
  url: string;
  year?: string;
  type?: string;
}