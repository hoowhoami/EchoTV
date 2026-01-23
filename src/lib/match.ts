import { ApiService, ApiSite } from './api';
import { SearchResult } from '@/types';

export class MatchService {
  /**
   * 跨所有站点搜索并尝试匹配最相似的资源
   */
  static async findAcrossSites(sites: ApiSite[], title: string, year?: string): Promise<SearchResult[]> {
    const searchPromises = sites.map(site => 
      ApiService.search(site, title).catch(() => [] as SearchResult[])
    );

    const allResults = await Promise.all(searchPromises);
    const flatResults = allResults.flat();

    // 简单的排序逻辑：标题完全匹配优先，年份匹配优先
    return flatResults.sort((a, b) => {
      const aTitleMatch = a.title === title ? 1 : 0;
      const bTitleMatch = b.title === title ? 1 : 0;
      if (aTitleMatch !== bTitleMatch) return bTitleMatch - aTitleMatch;

      if (year) {
        const aYearMatch = a.year === year ? 1 : 0;
        const bYearMatch = b.year === year ? 1 : 0;
        return bYearMatch - aYearMatch;
      }
      return 0;
    });
  }
}
