import { SearchResult } from '@/types';
import { SiteConfig } from '@/types/config';
import { storage, STORAGE_KEYS } from './storage';

export const DEFAULT_SITES: SiteConfig[] = [
  {
    key: 'lizi',
    name: '栗子资源',
    api: 'https://api.lziapi.com/api.php/provide/vod/',
    from: 'config'
  }
];

export class ApiService {
  /**
   * 获取通用 API 代理前缀
   * 仅用于解决采集站 CORS 跨域问题
   */
  private static getApiProxy() {
    return storage.get(STORAGE_KEYS.PROXY, '');
  }

  static async fetchList(site: SiteConfig, page = 1, typeId?: string | number): Promise<SearchResult[]> {
    try {
      const url = `${site.api}?ac=videolist&pg=${page}${typeId ? `&t=${typeId}` : ''}`;
      const proxy = this.getApiProxy();
      const finalUrl = proxy ? `${proxy}${encodeURIComponent(url)}` : url;
      
      const res = await fetch(finalUrl);
      if (!res.ok) return [];
      const data = await res.json();
      return this.parseCmsData(data, site);
    } catch (e) {
      console.error('ApiService.fetchList error:', e);
      return [];
    }
  }

  static async search(site: SiteConfig, keyword: string): Promise<SearchResult[]> {
    try {
      const url = `${site.api}?ac=videolist&wd=${encodeURIComponent(keyword)}`;
      const proxy = this.getApiProxy();
      const finalUrl = proxy ? `${proxy}${encodeURIComponent(url)}` : url;

      const res = await fetch(finalUrl);
      if (!res.ok) return [];
      const data = await res.json();
      return this.parseCmsData(data, site);
    } catch (e) {
      console.error('ApiService.search error:', e);
      return [];
    }
  }

  static async getDetail(site: SiteConfig, id: string): Promise<SearchResult | null> {
    try {
      const url = `${site.api}?ac=videolist&ids=${id}`;
      const proxy = this.getApiProxy();
      const finalUrl = proxy ? `${proxy}${encodeURIComponent(url)}` : url;

      const res = await fetch(finalUrl);
      if (!res.ok) return null;
      const data = await res.json();
      const results = this.parseCmsData(data, site);
      return results[0] || null;
    } catch (e) {
      console.error('ApiService.getDetail error:', e);
      return null;
    }
  }

  private static parseCmsData(data: any, site: SiteConfig): SearchResult[] {
    if (!data || !data.list) return [];
    
    return data.list.map((item: any) => {
      const playFrom = item.vod_play_from ? item.vod_play_from.split('$$$') : [];
      const playUrl = item.vod_play_url ? item.vod_play_url.split('$$$') : [];
      
      const playSources = playFrom.map((sourceName: string, index: number) => {
        const episodesRaw = playUrl[index] ? playUrl[index].split('#') : [];
        const episodes = episodesRaw.map((e: string) => {
          const parts = e.split('$');
          return parts.length > 1 ? parts[1] : parts[0];
        });
        const episodes_titles = episodesRaw.map((e: string) => e.split('$')[0]);
        
        return {
          name: sourceName,
          episodes,
          episodes_titles
        };
      }).filter(s => s.episodes.length > 0);

      // 默认选择第一个源作为基础数据以保持兼容性
      const defaultSource = playSources[0] || { episodes: [], episodes_titles: [] };

      return {
        id: item.vod_id,
        title: item.vod_name,
        poster: item.vod_pic,
        source: site.key,
        source_name: site.name,
        year: item.vod_year,
        class: item.vod_class,
        type_name: item.type_name,
        desc: item.vod_content,
        play_sources: playSources,
        episodes: defaultSource.episodes,
        episodes_titles: defaultSource.episodes_titles,
      };
    });
  }
}