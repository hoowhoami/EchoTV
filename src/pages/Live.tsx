import { useState, useEffect, useMemo } from 'react';
import { Tv, RefreshCcw, AlertCircle } from 'lucide-react';
import { ZenPlayer } from '@/components/ui/ZenPlayer';
import { storage, STORAGE_KEYS } from '@/lib/storage';
import { LiveService, LiveChannel } from '@/lib/live';
import { EpgService, EpgProgram } from '@/lib/epg';
import { AppConfig } from '@/types/config';
import { DEFAULT_SITES } from '@/lib/api';

export default function LivePage() {
  const [channels, setChannels] = useState<LiveChannel[]>([]);
  const [activeChannel, setActiveChannel] = useState<LiveChannel | null>(null);
  const [epg, setEpg] = useState<EpgProgram[]>([]);
  const [activeGroup, setActiveGroup] = useState<string>('全部');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function initLive() {
      setLoading(true);
      setError(null);
      try {
        const config = storage.get<AppConfig>(STORAGE_KEYS.SETTINGS, { sites: DEFAULT_SITES, lives: [] });
        if (config.lives.length > 0) {
          const data = await LiveService.fetchChannels(config.lives[0].url);
          if (data && data.length > 0) {
            setChannels(data);
            setActiveChannel(data[0]);
          } else { setError("该直播源未返回任何频道"); }
        } else { setError("未配置直播源，请前往设置"); }
      } catch (e) { setError("连接直播源失败，请检查网络或代理"); }
      setLoading(false);
    }
    initLive();
  }, []);

  useEffect(() => {
    if (activeChannel) {
      setEpg([]);
      EpgService.getPrograms(activeChannel.name).then(setEpg).catch(() => {});
    }
  }, [activeChannel]);

  const groups = useMemo(() => ['全部', ...new Set(channels.map(c => c.group))], [channels]);
  const filteredChannels = useMemo(() => activeGroup === '全部' ? channels : channels.filter(c => c.group === activeGroup), [channels, activeGroup]);

  return (
    <div className="flex flex-col md:flex-row overflow-hidden h-[calc(100vh-80px)] md:h-[calc(100vh-180px)] px-4 gap-6">
      <aside className="w-full md:w-64 bg-white/20 dark:bg-zinc-900/40 backdrop-blur-2xl border border-white/20 rounded-[32px] overflow-x-auto md:overflow-y-auto p-2 md:p-4 flex flex-row md:flex-col gap-1 shrink-0">
         {loading ? (
           <div className="flex flex-row md:flex-col gap-2 w-full animate-pulse">
              {[1,2,3,4].map(i => <div key={i} className="h-12 w-28 md:w-full bg-black/5 dark:bg-white/5 rounded-2xl" />)}
           </div>
         ) : (
           groups.map(group => (
             <button key={group} onClick={() => setActiveGroup(group)} className={`whitespace-nowrap px-5 py-3 rounded-2xl font-bold text-sm transition-all active-tactile ${activeGroup === group ? 'bg-black text-white dark:bg-white dark:text-black shadow-lg' : 'text-gray-500 hover:bg-black/5'}`}>{group}</button>
           ))
         )}
      </aside>

      <main className="flex-1 flex flex-col md:flex-row overflow-hidden bg-white/40 dark:bg-zinc-900/20 backdrop-blur-3xl rounded-[40px] border border-white/20 shadow-sm overflow-y-auto">
         <div className="w-full md:flex-[2] p-6 flex flex-col gap-6 shrink-0">
            {activeChannel ? (
              <div className="space-y-6">
                <ZenPlayer url={activeChannel.url} className="shadow-2xl rounded-[32px] border-4 border-white dark:border-zinc-800 aspect-video" />
                <div className="bg-white/60 dark:bg-zinc-800/40 p-8 rounded-[32px] border border-white/20">
                   <h2 className="text-3xl font-black tracking-tighter mb-1">{activeChannel.name}</h2>
                   <p className="text-sm font-bold text-gray-400 mb-6 uppercase tracking-widest">{activeChannel.group} • 实时直播</p>
                   {epg.length > 0 && <div className="p-4 bg-black/5 dark:bg-white/5 rounded-2xl"><h4 className="font-bold text-[10px] text-gray-400 mb-1 uppercase">正在播放</h4><p className="font-bold text-lg">{EpgService.getCurrentProgram(epg)?.title || '暂无节目信息'}</p></div>}
                </div>
              </div>
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-gray-300 py-20">
                 <Tv size={80} strokeWidth={1} className="opacity-10 mb-4" />
                 <p className="text-xs font-black uppercase tracking-[0.2em] opacity-40">请选择频道</p>
              </div>
            )}
         </div>

         <div className="w-full md:flex-1 bg-white/40 dark:bg-zinc-900/40 backdrop-blur-3xl border-t md:border-t-0 md:border-l border-white/20 overflow-y-auto p-4 custom-scrollbar">
            <div className="grid grid-cols-1 gap-2">
              {filteredChannels.map(channel => (
                <button key={channel.url} onClick={() => { setActiveChannel(channel); }} className={`flex items-center gap-4 p-3 rounded-2xl transition-all active-tactile text-left ${activeChannel?.url === channel.url ? 'bg-white dark:bg-zinc-800 shadow-md border border-black/5' : 'hover:bg-white/60 dark:hover:bg-white/5'}`}>
                  <div className="w-12 h-12 bg-black/5 dark:bg-white/5 rounded-xl flex items-center justify-center font-black text-xs text-gray-400">{channel.name[0]}</div>
                  <div className="flex-1 min-w-0"><p className={`font-bold text-sm truncate ${activeChannel?.url === channel.url ? 'text-black dark:text-white' : 'text-gray-600 dark:text-zinc-400'}`}>{channel.name}</p></div>
                </button>
              ))}
            </div>
         </div>
      </main>
    </div>
  );
}
