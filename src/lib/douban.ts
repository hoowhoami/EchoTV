import { DoubanSubject } from '@/types/config';
import { storage, STORAGE_KEYS } from './storage';

export type DoubanProxyType = 'custom' | 'tencent-cmlius' | 'aliyun-cmlius' | 'none';

export class DoubanService {
  /**
   * 获取豆瓣 API 基础地址
   * 优先使用专门的豆瓣镜像服务
   */
  private static getDoubanBase(subdomain: 'm' | 'movie'): string {
    const proxyType = storage.get(STORAGE_KEYS.DOUBAN_PROXY_TYPE, 'tencent-cmlius') as DoubanProxyType;
    switch (proxyType) {
      case 'tencent-cmlius': return `https://${subdomain}.douban.cmliussss.net`;
      case 'aliyun-cmlius': return `https://${subdomain}.douban.cmliussss.com`;
      default: return `https://${subdomain}.douban.com`;
    }
  }

  /**
   * 仅用于自定义豆瓣代理（如果需要）
   */
  private static getDoubanProxyPrefix(): string {
    return storage.get(STORAGE_KEYS.DOUBAN_PROXY_TYPE, 'tencent-cmlius') === 'custom' 
      ? storage.get(STORAGE_KEYS.DOUBAN_PROXY, '') 
      : '';
  }

  static async getList(type: 'movie' | 'tv', tag = '热门', pageStart = 0): Promise<DoubanSubject[]> {
    try {
      const baseUrl = this.getDoubanBase('movie');
      const targetUrl = `${baseUrl}/j/search_subjects?type=${type}&tag=${encodeURIComponent(tag)}&page_limit=24&page_start=${pageStart}`;
      const proxy = this.getDoubanProxyPrefix();
      const res = await fetch(proxy ? `${proxy}${encodeURIComponent(targetUrl)}` : targetUrl);
      const data = await res.json();
      return (data.subjects || []).map((s: any) => ({
        id: s.id, title: s.title, rate: s.rate, cover: s.cover, url: s.url
      }));
    } catch (e) { return []; }
  }

  static async getRexxarList(kind: string, category: string, type: string, pageStart = 0): Promise<DoubanSubject[]> {
    try {
      const baseUrl = this.getDoubanBase('m');
      const params = new URLSearchParams({
        start: pageStart.toString(),
        count: '24',
        category: category,
        type: type
      });

      const targetUrl = `${baseUrl}/rexxar/api/v2/subject/recent_hot/${kind}?${params.toString()}`;
      const proxy = this.getDoubanProxyPrefix();
      const res = await fetch(proxy ? `${proxy}${encodeURIComponent(targetUrl)}` : targetUrl);
      const data = await res.json();
      
      return (data.items || []).map((s: any) => ({
        id: s.id, title: s.title, rate: s.rating?.value?.toFixed(1) || '0.0',
        cover: s.pic?.normal || s.pic?.large || '', url: '', year: s.card_subtitle?.match(/(\d{4})/)?.[1] || s.year
      }));
    } catch (e) { return []; }
  }

  static async getRecommendList(kind: string, filters: Record<string, string>, pageStart = 0): Promise<DoubanSubject[]> {
    try {
      const baseUrl = this.getDoubanBase('m');
      const tags: string[] = [];
      const selectedCategories: Record<string, string> = {};

      if (filters.type && filters.type !== 'all') {
        tags.push(filters.type);
        selectedCategories['类型'] = filters.type;
      }
      if (filters.region && filters.region !== 'all') {
        tags.push(filters.region);
        selectedCategories['地区'] = filters.region;
      }
      if (filters.year && filters.year !== 'all') tags.push(filters.year);
      if (filters.platform && filters.platform !== 'all') tags.push(filters.platform);

      const params = new URLSearchParams({
        refresh: '0',
        start: pageStart.toString(),
        count: '24',
        uncollect: 'false',
        score_range: '0,10',
        tags: tags.join(','),
        selected_categories: JSON.stringify(selectedCategories)
      });

      if (filters.sort && filters.sort !== 'T') params.append('sort', filters.sort);

      const targetUrl = `${baseUrl}/rexxar/api/v2/${kind}/recommend?${params.toString()}`;
      const proxy = this.getDoubanProxyPrefix();
      const res = await fetch(proxy ? `${proxy}${encodeURIComponent(targetUrl)}` : targetUrl);
      const data = await res.json();
      
      return (data.items || []).filter((item: any) => item.type === 'movie' || item.type === 'tv').map((s: any) => ({
        id: s.id, title: s.title, rate: s.rating?.value?.toFixed(1) || '0.0',
        cover: s.pic?.normal || s.pic?.large || '', url: '', year: s.year
      }));
    } catch (e) { return []; }
  }

  static async getRecommends(kind: 'movie' | 'tv' | 'show'): Promise<DoubanSubject[]> {
    try {
      const category = kind === 'movie' ? '热门' : kind;
      const type = kind === 'movie' ? '全部' : kind;
      const realKind = kind === 'show' ? 'tv' : kind;
      return await this.getRexxarList(realKind, category, type, 0);
    } catch (e) { return []; }
  }

  static getImageUrl(url: string): string {
    if (!url) return '';
    const proxyType = storage.get(STORAGE_KEYS.DOUBAN_PROXY_TYPE, 'tencent-cmlius');
    if (proxyType === 'tencent-cmlius') {
      return url.replace('img1.doubanio.com', 'img1.douban.cmliussss.net').replace('img3.doubanio.com', 'img3.douban.cmliussss.net');
    }
    return url;
  }
}