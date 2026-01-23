export interface BangumiCalendarData {
  weekday: {
    en: string;
    cn?: string;
  };
  items: {
    id: number;
    name: string;
    name_cn: string;
    rating: {
      score: number;
    };
    air_date: string;
    images: {
      large: string;
      common: string;
      medium: string;
      small: string;
      grid: string;
    };
  }[];
}

export class BangumiService {
  static async getCalendar(): Promise<BangumiCalendarData[]> {
    try {
      const response = await fetch('https://api.bgm.tv/calendar');
      const data = await response.json();
      return data.map((item: BangumiCalendarData) => ({
        ...item,
        items: item.items.filter(i => i.images)
      }));
    } catch (e) {
      console.error('BangumiService.getCalendar error:', e);
      return [];
    }
  }
}
