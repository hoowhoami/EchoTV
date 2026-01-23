export interface EpgProgram {
  start: string;
  end: string;
  title: string;
  desc?: string;
}

export class EpgService {
  private static DEFAULT_EPG_API = 'https://epg.112114.xyz/?ch=';

  /**
   * 获取指定频道的节目单
   * @param channelName 频道名称 (如 'CCTV1')
   */
  static async getPrograms(channelName: string): Promise<EpgProgram[]> {
    try {
      // 这是一个公共的 EPG 代理接口
      const res = await fetch(`${this.DEFAULT_EPG_API}${encodeURIComponent(channelName)}`);
      const data = await res.json();
      return data.epg_data || [];
    } catch (e) {
      console.error('Fetch EPG failed:', e);
      return [];
    }
  }

  /**
   * 获取当前正在播放的节目
   */
  static getCurrentProgram(programs: EpgProgram[]): EpgProgram | null {
    const now = new Date();
    const nowStr = now.getHours().toString().padStart(2, '0') + ':' + now.getMinutes().toString().padStart(2, '0');
    
    return programs.find(p => p.start <= nowStr && p.end > nowStr) || null;
  }
}
