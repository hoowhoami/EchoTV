export const STORAGE_KEYS = {
  SETTINGS: 'mixtv_settings',
  HISTORY: 'mixtv_history',
  FAVORITES: 'mixtv_favorites',
  PROXY: 'mixtv_api_proxy', // 通用 API 代理
  DOUBAN_PROXY: 'mixtv_douban_proxy', // 豆瓣自定义代理
  DOUBAN_PROXY_TYPE: 'mixtv_douban_proxy_type', // 豆瓣代理类型
};

export const storage = {
  get: <T>(key: string, defaultValue: T): T => {
    const val = localStorage.getItem(key);
    if (!val) return defaultValue;
    try {
      return JSON.parse(val) as T;
    } catch {
      return val as unknown as T;
    }
  },
  set: (key: string, value: any) => {
    localStorage.setItem(key, typeof value === 'string' ? value : JSON.stringify(value));
  }
};