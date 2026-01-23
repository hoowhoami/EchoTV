export interface LiveChannel {
  name: string;
  url: string;
  logo?: string;
  group: string;
}

export class LiveService {
  /**
   * 解析 M3U 格式的直播源
   */
  static parseM3U(content: string): LiveChannel[] {
    const channels: LiveChannel[] = [];
    const lines = content.split('\n');
    let currentChannel: Partial<LiveChannel> = {};

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        const nameMatch = line.match(/,(.*)$/);
        const groupMatch = line.match(/group-title="(.*?)"/);
        const logoMatch = line.match(/tvg-logo="(.*?)"/);
        
        currentChannel = {
          name: nameMatch ? nameMatch[1] : 'Unknown Channel',
          group: groupMatch ? groupMatch[1] : 'Others',
          logo: logoMatch ? logoMatch[1] : '',
        };
      } else if (line.startsWith('http')) {
        currentChannel.url = line;
        channels.push(currentChannel as LiveChannel);
        currentChannel = {};
      }
    }
    return channels;
  }

  /**
   * 获取远程直播源并解析
   */
  static async fetchChannels(url: string): Promise<LiveChannel[]> {
    try {
      const res = await fetch(url);
      const text = await res.text();
      if (text.includes('#EXTM3U')) {
        return this.parseM3U(text);
      }
      // 这里可以扩展 TXT 格式解析
      return [];
    } catch (e) {
      console.error('Fetch live channels failed:', e);
      return [];
    }
  }
}
