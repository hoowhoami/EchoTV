import { AppConfig, SiteConfig, LiveSource, CustomCategory } from '@/types/config';

export class SubscriptionService {
  /**
   * 解析配置文件 (支持标准 JSON 格式)
   */
  static parseConfig(jsonStr: string): AppConfig {
    let raw: any = {};
    try {
      raw = JSON.parse(jsonStr);
    } catch (e) {
      console.error('JSON parse error');
    }

    const sites: SiteConfig[] = [];
    if (raw.api_site) {
      Object.entries(raw.api_site).forEach(([key, val]: [string, any]) => {
        sites.push({
          key,
          name: val.name,
          api: val.api,
          detail: val.detail,
          from: 'config'
        });
      });
    }

    const lives: LiveSource[] = [];
    if (raw.lives) {
      Object.entries(raw.lives).forEach(([key, val]: [string, any]) => {
        lives.push({
          key,
          name: val.name,
          url: val.url,
          ua: val.ua,
          epg: val.epg,
          from: 'config'
        });
      });
    }

    return {
      api_site: raw.api_site || {},
      lives: raw.lives || {},
      custom_category: raw.custom_category || [],
      cache_time: raw.cache_time || 7200,
      sites,
      live_configs: lives,
      categories: (raw.custom_category || []).map((c: any) => ({ ...c, from: 'config' })),
      announcement: raw.announcement || '',
      site_name: raw.site_name || 'MixTV'
    };
  }

  /**
   * 将内部状态导出为标准的配置文件格式
   */
  static exportConfig(config: AppConfig): string {
    const api_site: any = {};
    (config.sites || []).forEach(s => {
      if (s.key) api_site[s.key] = { name: s.name, api: s.api, detail: s.detail };
    });

    const lives: any = {};
    (config.live_configs || []).forEach(l => {
      const key = l.key || l.url;
      if (key) lives[key] = { name: l.name, url: l.url, ua: l.ua, epg: l.epg };
    });

    const result = {
      cache_time: config.cache_time || 7200,
      api_site,
      lives,
      custom_category: (config.categories || []).map(c => ({ name: c.name, type: c.type, query: c.query }))
    };

    return JSON.stringify(result, null, 2);
  }

  static async fetchSubscription(url: string): Promise<AppConfig> {
    const response = await fetch(url);
    const text = await response.text();
    return this.parseConfig(text);
  }
}
