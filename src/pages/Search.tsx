import { useState, useEffect, useMemo } from 'react';
import { Search as SearchIcon, ChevronLeft, Loader2, Sparkles } from 'lucide-react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ZenButton } from '@/components/ui/ZenButton';
import { SearchFilter } from '@/components/ui/SearchFilter';
import { ApiService, DEFAULT_SITES } from '@/lib/api';
import { storage, STORAGE_KEYS } from '@/lib/storage';
import { SearchResult } from '@/types';
import { AppConfig } from '@/types/config';

export default function SearchPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const queryQ = searchParams.get('q') || '';

  const [keyword, setKeyword] = useState(queryQ);
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [activeSiteKey, setActiveSiteKey] = useState<string>('all');
  const [activeClass, setActiveClass] = useState<string>('all');
  const [isAggregate, setIsAggregate] = useState(true);
  const [config, setConfig] = useState<AppConfig>({ sites: [], lives: [] });

  useEffect(() => {
    const saved = storage.get<AppConfig>(STORAGE_KEYS.SETTINGS, { sites: DEFAULT_SITES, lives: [] });
    setConfig(saved);
    if (queryQ) { handleSearch(queryQ, saved.sites); }
  }, [queryQ]);

  const handleSearch = async (kw: string, sites = config.sites) => {
    if (!kw.trim()) return;
    setLoading(true);
    setSearchParams({ q: kw });
    try {
      const promises = sites.map(site => ApiService.search(site as any, kw).catch(() => []));
      const allResults = await Promise.all(promises);
      setResults(allResults.flat());
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  };

  const filteredResults = useMemo(() => {
    return results.filter(item => {
      const siteMatch = activeSiteKey === 'all' || item.source === activeSiteKey;
      const classMatch = activeClass === 'all' || item.type_name === activeClass;
      return siteMatch && classMatch;
    });
  }, [results, activeSiteKey, activeClass]);

  // LunaTV 核心聚合逻辑
  const aggregatedResults = useMemo(() => {
    if (!isAggregate) return filteredResults.map(r => ({ key: `${r.source}-${r.id}`, items: [r] }));
    
    const groups = new Map<string, SearchResult[]>();
    filteredResults.forEach(item => {
      const key = `${item.title.replace(/\s+/g, '')}-${item.year || 'unknown'}-${item.episodes.length > 1 ? 'tv' : 'movie'}`;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(item);
    });

    return Array.from(groups.entries()).map(([key, items]) => ({
      key,
      items,
      main: items[0],
      sources: Array.from(new Set(items.map(i => i.source_name)))
    }));
  }, [filteredResults, isAggregate]);

  return (
    <div className="px-6 md:px-12">
      {/* 📱 搜索头部 */}
      <div className="fixed top-0 left-0 w-full z-40 bg-white/60 dark:bg-black/60 backdrop-blur-3xl border-b border-white/10 p-4 md:p-6">
        <div className="max-w-6xl mx-auto space-y-4">
          <div className="flex items-center gap-4">
            <div className="flex-1 relative group">
              <SearchIcon className="absolute left-5 top-1/2 -translate-y-1/2 text-gray-400 size-5" />
              <input 
                autoFocus type="text" placeholder="探索精彩影视..."
                className="w-full bg-black/5 dark:bg-white/5 border-2 border-transparent focus:bg-white dark:focus:bg-zinc-900 rounded-[24px] py-4 pl-14 pr-6 font-bold text-base md:text-lg outline-none transition-all shadow-inner"
                value={keyword} onChange={(e) => setKeyword(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSearch(keyword)}
              />
            </div>
            <ZenButton variant="primary" className="rounded-full px-8 h-14 hidden sm:flex" onClick={() => handleSearch(keyword)} disabled={loading}>
              {loading ? <Loader2 className="animate-spin size-5" /> : '搜索'}
            </ZenButton>
          </div>

          {results.length > 0 && (
            <div className="flex flex-col gap-2 pt-2 animate-in slide-in-from-top-2 duration-300">
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <SearchFilter 
                    label="来源站点" 
                    options={[{ label: '全部来源', value: 'all' }, ...config.sites.map(s => ({ label: s.name, value: s.key }))]} 
                    activeValue={activeSiteKey} 
                    onChange={setActiveSiteKey} 
                  />
                </div>
                
                {/* 聚合开关 */}
                <div className="flex items-center gap-3 ml-4 bg-black/5 dark:bg-white/5 p-1.5 px-4 rounded-full border border-black/5">
                   <span className="text-[10px] font-black uppercase tracking-widest text-gray-400">聚合搜索</span>
                   <button 
                    onClick={() => setIsAggregate(!isAggregate)}
                    className={cn(
                      "w-10 h-5 rounded-full transition-all relative",
                      isAggregate ? "bg-black dark:bg-white" : "bg-gray-300 dark:bg-zinc-700"
                    )}
                   >
                     <div className={cn(
                       "absolute top-1 w-3 h-3 rounded-full transition-all",
                       isAggregate ? "right-1 bg-white dark:bg-black" : "left-1 bg-white"
                     )} />
                   </button>
                </div>
              </div>
              
              <SearchFilter 
                label="视频分类" 
                options={[{ label: '全部类型', value: 'all' }, ...Array.from(new Set(results.map(r => r.type_name))).filter(Boolean).map(c => ({ label: c as string, value: c as string }))]} 
                activeValue={activeClass} 
                onChange={setActiveClass} 
              />
            </div>
          )}
        </div>
      </div>

      <main className="pt-40 md:pt-64">
        {!loading && results.length === 0 && (
          <div className="flex flex-col items-center justify-center py-40 text-gray-300">
            <Sparkles size={64} className="mb-6 opacity-10" />
            <h2 className="text-xl font-black tracking-widest uppercase opacity-40">开启探索之旅</h2>
          </div>
        )}

        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-6 md:gap-10 pb-20">
          {aggregatedResults.map((group) => {
            const item = group.items[0];
            const isAgg = isAggregate && group.items.length > 1;
            
            return (
              <div 
                key={group.key} 
                className="group cursor-pointer active-tactile" 
                onClick={() => {
                  if (isAgg) {
                    navigate(`/play?title=${encodeURIComponent(item.title)}&year=${item.year || ''}`);
                  } else {
                    navigate(`/play?id=${item.id}&source=${item.source}`);
                  }
                }}
              >
                <div className="relative aspect-[2/3] rounded-[32px] overflow-hidden bg-gray-100 dark:bg-zinc-900 border border-white/10 shadow-sm mb-3">
                  <img src={item.poster} className="w-full h-full object-cover transition-transform group-hover:scale-110" loading="lazy" />
                  
                  {/* 聚合标识 */}
                  {isAgg ? (
                    <div className="absolute top-3 right-3 px-2 py-0.5 bg-green-500 backdrop-blur-md rounded-lg text-[9px] font-black text-white uppercase border border-white/10">
                      {group.items.length} 来源
                    </div>
                  ) : (
                    <div className="absolute top-3 left-3 px-2 py-0.5 bg-black/60 backdrop-blur-md rounded-lg text-[9px] font-black text-white uppercase border border-white/10">
                      {item.source_name}
                    </div>
                  )}

                  {item.episodes.length > 1 && (
                    <div className="absolute bottom-3 right-3 px-2 py-0.5 bg-white text-black rounded-lg text-[9px] font-black uppercase">
                      {item.episodes.length} 集
                    </div>
                  )}
                </div>
                <h4 className="text-sm font-bold tracking-tight truncate px-1">{item.title}</h4>
                <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-1 px-1">
                  {item.year} • {isAgg ? '聚合' : item.type_name}
                </p>
              </div>
            );
          })}
        </div>
      </main>
    </div>
  );
}