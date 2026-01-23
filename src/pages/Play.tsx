import { useEffect, useState, useRef, useMemo } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { ListVideo, Layers, ExternalLink, Loader2, Check } from 'lucide-react';
import { ZenPlayer } from '@/components/ui/ZenPlayer';
import { ApiService, DEFAULT_SITES } from '@/lib/api';
import { MatchService } from '@/lib/match';
import { storage, STORAGE_KEYS } from '@/lib/storage';
import { SearchResult, PlayRecord } from '@/types';
import { AppConfig } from '@/types/config';
import { cn } from '@/lib/utils';

export default function Play() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const id = searchParams.get('id');
  const sourceKey = searchParams.get('source');
  const title = searchParams.get('title');
  const year = searchParams.get('year');
  
  const [detail, setDetail] = useState<SearchResult | null>(null);
  const [allMatchedResults, setAllMatchedResults] = useState<SearchResult[]>([]); // 缓存全网搜索结果
  const [activeEpisode, setActiveEpisode] = useState(0);
  const [activeSourceIndex, setActiveSourceIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [matching, setMatching] = useState(false);
  const [activeTab, setActiveTab] = useState<'episodes' | 'sources'>('episodes');
  
  const prevTitleRef = useRef<string | null>(null);

  // 衍生状态：过滤掉当前正在播放的源
  const otherSources = useMemo(() => {
    return allMatchedResults.filter(r => r.source !== sourceKey || r.id !== id);
  }, [allMatchedResults, sourceKey, id]);

  useEffect(() => {
    async function loadDetail() {
      // 只有在完全没有数据时才显示全屏 Loading
      if (!detail) setLoading(true);
      
      const config = storage.get<AppConfig>(STORAGE_KEYS.SETTINGS, { sites: DEFAULT_SITES, lives: [] });
      let currentDetail: SearchResult | null = null;

      // 1. 加载当前选中的详情
      if (id && sourceKey) {
        const site = config.sites.find(s => s.key === sourceKey) || config.sites[0];
        currentDetail = await ApiService.getDetail(site as any, id);
      } else if (title) {
        // 如果是从搜索跳转过来只有标题，先找一个最佳匹配
        const results = await MatchService.findAcrossSites(config.sites as any, title, year || '');
        if (results.length > 0) {
          setAllMatchedResults(results); // 存入缓存
          const bestMatch = results[0];
          currentDetail = await ApiService.getDetail(config.sites.find(s => s.key === bestMatch.source) as any, bestMatch.id);
        }
      }

      if (currentDetail) {
        const isSameMovie = prevTitleRef.current === currentDetail.title;
        setDetail(currentDetail);

        // 2. 只有“换片”时才重置集数或加载历史，且触发全网搜索
        if (!isSameMovie) {
          const history = storage.get<PlayRecord[]>(STORAGE_KEYS.HISTORY, []);
          const record = history.find(r => r.source === currentDetail!.source && r.title === currentDetail!.title);
          setActiveEpisode(record ? record.episode_index : 0);
          setActiveSourceIndex(0);

          // 触发全网搜索（换片才搜）
          setMatching(true);
          MatchService.findAcrossSites(config.sites as any, currentDetail.title, currentDetail.year || year || '').then(results => {
             setAllMatchedResults(results);
             setMatching(false);
          }).catch(() => setMatching(false));
        } else {
          // 3. “换源”时：保持集数，不触发搜索，仅做集数越界检查
          const maxEpisodes = currentDetail.play_sources?.[activeSourceIndex]?.episodes.length || currentDetail.episodes.length;
          if (activeEpisode >= maxEpisodes) {
            setActiveEpisode(0);
          }
        }
        
        prevTitleRef.current = currentDetail.title;
      }
      
      setLoading(false);
    }
    loadDetail();
  }, [id, sourceKey, title, year]);

  if (loading && !detail) {
    return (
      <div className="h-[80vh] flex flex-col items-center justify-center gap-4 text-gray-400">
        <Loader2 className="animate-spin opacity-20" size={32} />
        <div className="font-black uppercase tracking-widest text-[10px] opacity-40">Loading Media...</div>
      </div>
    );
  }

  if (!detail) return <div className="h-[60vh] flex items-center justify-center opacity-40 font-black uppercase tracking-widest">Source Error</div>;

  const currentSource = detail.play_sources?.[activeSourceIndex] || { episodes: detail.episodes, episodes_titles: detail.episodes_titles, name: '默认' };

  return (
    <div className="px-6 md:px-12 max-w-[1800px] mx-auto space-y-8 pb-12 animate-in fade-in duration-700">
      <div className="flex flex-col xl:flex-row gap-6 md:gap-8 items-stretch h-auto">
        {/* 🎬 Player Container - Fixed Aspect Ratio */}
        <div className="flex-[3.5] relative group overflow-hidden rounded-[40px] shadow-[0_32px_64px_-16px_rgba(0,0,0,0.12)] bg-black ring-1 ring-white/20 aspect-video self-start">
          <ZenPlayer 
            url={currentSource.episodes[activeEpisode]} 
            title={detail.title}
            poster={detail.poster}
            className="w-full h-full border-none"
          />
          {loading && (
            <div className="absolute inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
              <Loader2 className="animate-spin text-white/80" size={40} />
            </div>
          )}
        </div>

        {/* 📱 Right Side Interaction Panel - Height Locked to Player */}
        <div className="xl:w-[460px] flex flex-col shrink-0 relative min-h-[500px] xl:min-h-0">
          <div className="xl:absolute xl:inset-0 bg-white/40 dark:bg-zinc-900/40 backdrop-blur-[60px] rounded-[40px] border border-white/60 dark:border-white/10 flex flex-col shadow-[0_12px_40px_-4px_rgba(0,0,0,0.05)] overflow-hidden">
            
            {/* 📍 Tab Switcher */}
            <div className="p-6 border-b border-black/[0.03] dark:border-white/[0.03] shrink-0">
              <div className="flex gap-1 p-1 bg-black/[0.04] dark:bg-black/40 rounded-2xl shadow-inner border border-black/[0.02] dark:border-white/[0.02]">
                <button 
                  onClick={() => setActiveTab('episodes')}
                  className={cn(
                    "flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-[11px] font-black uppercase transition-all duration-300 active:scale-95",
                    activeTab === 'episodes' 
                      ? "bg-white dark:bg-zinc-800 text-black dark:text-white shadow-lg" 
                      : "text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                  )}
                >
                  <ListVideo size={14} />
                  选集播放
                </button>
                <button 
                  onClick={() => setActiveTab('sources')}
                  className={cn(
                    "flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-[11px] font-black uppercase transition-all duration-300 active:scale-95",
                    activeTab === 'sources' 
                      ? "bg-white dark:bg-zinc-800 text-black dark:text-white shadow-lg" 
                      : "text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                  )}
                >
                  <div className="relative">
                    <Layers size={14} />
                    {(matching || loading) && <div className="absolute -top-1 -right-1 w-2 h-2 bg-black dark:bg-white rounded-full animate-ping" />}
                  </div>
                  线路切换
                </button>
              </div>
            </div>

            {/* 🎞️ Scrollable Content Area */}
            <div className="flex-1 overflow-y-auto custom-scrollbar">
              {activeTab === 'episodes' ? (
                <div className="p-6">
                  <div className="grid grid-cols-3 gap-2.5">
                    {currentSource.episodes.map((ep, idx) => (
                      <button
                        key={idx}
                        onClick={() => { setActiveEpisode(idx); }}
                        className={cn(
                          "relative h-12 rounded-2xl font-bold text-[11px] transition-all duration-300 active:scale-95 border flex items-center justify-center",
                          activeEpisode === idx 
                            ? "bg-black text-white dark:bg-white dark:text-black shadow-xl border-transparent" 
                            : "bg-white/60 dark:bg-white/5 text-gray-500 border-black/[0.03] dark:border-white/[0.05] hover:bg-white dark:hover:bg-white/10"
                        )}
                      >
                        <span className="truncate px-2">{currentSource.episodes_titles[idx] || `${idx + 1}`}</span>
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="p-6 space-y-8">
                  {/* Internal Lines */}
                  {detail.play_sources && detail.play_sources.length > 1 && (
                    <div className="space-y-4">
                      <span className="text-[10px] font-black uppercase tracking-widest text-gray-400 px-1">站内线路</span>
                      <div className="grid grid-cols-2 gap-2">
                        {detail.play_sources.map((source, idx) => (
                          <button
                            key={idx}
                            onClick={() => { setActiveSourceIndex(idx); }}
                            className={cn(
                              "px-4 py-3 rounded-2xl text-[10px] font-black uppercase transition-all border flex items-center justify-between group",
                              activeSourceIndex === idx 
                                ? "bg-black text-white dark:bg-white dark:text-black border-transparent shadow-lg" 
                                : "bg-black/[0.03] dark:bg-white/5 text-gray-400 border-black/[0.03] dark:border-white/[0.05] hover:bg-black/5"
                            )}
                          >
                            <span className="truncate">{source.name}</span>
                            {activeSourceIndex === idx && <Check size={12} className="shrink-0" />}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* External Sources */}
                  <div className="space-y-4">
                    <span className="text-[10px] font-black uppercase tracking-widest text-gray-400 px-1">全网线路</span>
                    {matching && otherSources.length === 0 ? (
                      <div className="py-10 flex flex-col items-center justify-center gap-4 text-gray-400">
                        <Loader2 size={24} className="animate-spin opacity-40" />
                        <p className="text-[10px] font-black uppercase tracking-widest opacity-40 text-center">正在同步全球节点...</p>
                      </div>
                    ) : otherSources.length > 0 ? (
                      <div className="space-y-2.5">
                        {otherSources.map(source => (
                          <button 
                            key={source.id} 
                            onClick={() => { navigate(`/play?id=${source.id}&source=${source.source}`); }} 
                            className="w-full flex items-center justify-between p-4 bg-white/40 dark:bg-white/5 rounded-2xl border border-black/[0.03] dark:border-white/[0.03] hover:bg-white dark:hover:bg-white/10 transition-all duration-300 active:scale-[0.98] group shadow-sm"
                          >
                             <div className="flex flex-col items-start gap-1">
                               <span className="px-2 py-0.5 bg-black dark:bg-white text-white dark:text-black text-[9px] font-black rounded-lg uppercase">
                                 {source.source_name}
                               </span>
                               <span className="text-[10px] text-gray-400 font-bold uppercase tracking-wider">瞬时连接</span>
                             </div>
                             <ExternalLink size={14} className="text-gray-300 group-hover:text-black dark:group-hover:text-white transition-colors" />
                          </button>
                        ))}
                      </div>
                    ) : (
                      <div className="py-20 flex flex-col items-center justify-center text-gray-300">
                        <Layers size={40} className="opacity-10 mb-4" />
                        <p className="text-[10px] font-black uppercase tracking-widest opacity-40 text-center px-10">暂无其他线路<br/>建议尝试当前站点其他线路</p>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* 📝 Details Information & Poster */}
      <div className="bg-white/40 dark:bg-zinc-900/40 backdrop-blur-[40px] rounded-[40px] p-8 md:p-12 border border-white/60 dark:border-white/10 shadow-[0_8px_32px_rgba(0,0,0,0.02)] flex flex-col md:flex-row gap-10">
        <div className="w-full md:w-[240px] shrink-0">
          <div className="aspect-[2/3] rounded-[40px] overflow-hidden shadow-2xl ring-1 ring-black/5">
            <img 
              src={detail.poster} 
              alt={detail.title} 
              className="w-full h-full object-cover"
            />
          </div>
        </div>
        <div className="flex-1">
          <div className="flex flex-wrap items-center gap-3 mb-8">
            <span className="px-3 py-1.5 bg-black/[0.03] dark:bg-white/10 text-[10px] font-black rounded-xl uppercase text-gray-500 dark:text-gray-400">
              {detail.year} • {detail.type_name}
            </span>
            <span className="px-3 py-1.5 bg-black dark:bg-white text-white dark:text-black text-[10px] font-black rounded-xl uppercase">
              {detail.source_name}
            </span>
          </div>
          <h1 className="text-4xl md:text-6xl font-black tracking-tighter mb-8 text-black dark:text-white leading-[1.1]">{detail.title}</h1>
          <div className="text-sm md:text-lg text-gray-500 dark:text-zinc-400 font-medium leading-[1.8] max-w-5xl" 
               dangerouslySetInnerHTML={{ __html: detail.desc || '暂无简介' }} />
        </div>
      </div>
    </div>
  );
}