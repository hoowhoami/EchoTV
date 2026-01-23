import { useState, useEffect } from 'react';
import { RefreshCcw } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { ZenButton } from '@/components/ui/ZenButton';
import { MovieCard } from '@/components/ui/MovieCard';
import { DoubanService } from '@/lib/douban';
import { BangumiService } from '@/lib/bangumi';
import { DoubanSubject } from '@/types/config';
import { DoubanFilter } from '@/components/ui/DoubanFilter';
import { AdvancedFilter } from '@/components/ui/AdvancedFilter';

interface ExploreProps {
  title: string;
  type: 'movie' | 'tv' | 'show' | 'anime';
}

export default function ExplorePage({ title, type }: ExploreProps) {
  const navigate = useNavigate();
  const [items, setItems] = useState<DoubanSubject[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);

  const getInitialPrimary = (t: string) => {
    if (t === 'movie') return '热门';
    if (t === 'tv' || t === 'show') return '最近热门';
    if (t === 'anime') return '每日放送';
    return '热门';
  };

  const getInitialSecondary = (t: string) => {
    if (t === 'tv') return 'tv';
    if (t === 'show') return 'show';
    return '全部';
  };

  const [activePrimary, setActivePrimary] = useState(() => getInitialPrimary(type));
  const [activeSecondary, setActiveSecondary] = useState(() => getInitialSecondary(type));
  const [advancedFilters, setAdvancedFilters] = useState<Record<string, string>>({
    type: '', region: '', year: '', sort: 'T', platform: ''
  });

  const isAdvancedMode = activePrimary === '全部';

  useEffect(() => {
    const initialP = getInitialPrimary(type);
    const initialS = getInitialSecondary(type);
    setActivePrimary(initialP);
    setActiveSecondary(initialS);
    setAdvancedFilters({ type: '', region: '', year: '', sort: 'T', platform: '' });
    setItems([]);
    setPage(0);
  }, [type]);

  useEffect(() => {
    let isMounted = true;
    const controller = new AbortController();

    async function load() {
      setLoading(true);
      if (page === 0) setItems([]);
      
      let results: DoubanSubject[] = [];
      const start = page;

      try {
        if (isAdvancedMode) {
          const kind = type === 'show' ? 'tv' : (type === 'anime' ? 'tv' : type);
          const filters = { ...advancedFilters };
          if (type === 'anime') filters.type = '动画';
          if (type === 'show') filters.type = '综艺';
          results = await DoubanService.getRecommendList(kind, filters, start);
        } else {
          // 普通模式
          if (type === 'anime' && activePrimary === '每日放送') {
             const calendar = await BangumiService.getCalendar();
             const weekdayMap: Record<string, string> = {
               mon: 'Monday', tue: 'Tuesday', wed: 'Wednesday', thu: 'Thursday', 
               fri: 'Friday', sat: 'Saturday', sun: 'Sunday', all: ''
             };
             const targetDay = weekdayMap[activeSecondary];
             if (targetDay) {
               const dayData = calendar.find(d => d.weekday.en === targetDay);
               results = (dayData?.items || []).map(item => ({
                 id: item.id.toString(),
                 title: item.name_cn || item.name,
                 rate: item.rating?.score?.toFixed(1) || '0.0',
                 cover: item.images?.large || '',
                 url: '',
                 year: item.air_date?.split('-')[0] || ''
               }));
             } else {
               // "全部" 模式：聚合所有
               results = calendar.flatMap(d => d.items.map(item => ({
                 id: item.id.toString(),
                 title: item.name_cn || item.name,
                 rate: item.rating?.score?.toFixed(1) || '0.0',
                 cover: item.images?.large || '',
                 url: '',
                 year: item.air_date?.split('-')[0] || ''
               })));
             }
          } else {
             if (type === 'movie' && (activePrimary === '热门' || activePrimary === '最新')) {
               const tag = activeSecondary === '全部' ? activePrimary : activeSecondary;
               results = await DoubanService.getList('movie', tag, start);
             } else {
               // Rexxar Recent Hot 模式
               let kind = type === 'show' ? 'tv' : (type === 'anime' ? 'tv' : type);
               let category = type === 'show' ? 'show' : (type === 'anime' ? (activePrimary === '剧场版' ? 'movie' : 'tv') : type);
               let subType = activeSecondary;
               
               // 如果是动漫，且不是每日放送，则根据一级分类(番剧/剧场版)进行筛选
               if (type === 'anime') {
                  const filters: Record<string, string> = { type: '动画' };
                  if (activePrimary === '剧场版') {
                    results = await DoubanService.getRecommendList('movie', filters, start);
                  } else {
                    if (activeSecondary !== '全部' && activeSecondary !== 'all') filters.region = activeSecondary;
                    results = await DoubanService.getRecommendList('tv', filters, start);
                  }
               } else {
                  results = await DoubanService.getRexxarList(kind, category, subType, start);
               }
             }
          }
        }

        if (isMounted) {
          setItems(prev => start === 0 ? results : [...prev, ...results]);
          setLoading(false);
        }
      } catch (e) {
        if (isMounted) setLoading(false);
      }
    }

    load();

    return () => {
      isMounted = false;
      controller.abort();
    };
  }, [type, activePrimary, activeSecondary, advancedFilters, page]);

  async function handleLoadMore() {
    setPage(prev => prev + 24);
  }

  return (
    <div className="px-4 md:px-12 max-w-[1600px] mx-auto animate-in fade-in duration-500">
      <header className="space-y-6 mb-10">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl md:text-4xl font-black tracking-tighter">{title}</h1>
          <ZenButton variant="ghost" size="sm" className="rounded-full h-10 w-10 p-0" onClick={() => { setPage(0); setItems([]); }}>
            <RefreshCcw size={18} className={loading ? 'animate-spin' : ''} />
          </ZenButton>
        </div>

        <div className="relative z-30 bg-white/40 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[32px] p-4 md:p-8 border border-white/20 shadow-sm">
           <DoubanFilter 
            mode="primary"
            type={type}
            activePrimary={activePrimary}
            activeSecondary={activeSecondary}
            onChange={(val) => { 
              setActivePrimary(val); 
              setActiveSecondary(getInitialSecondary(type)); 
              setPage(0); 
            }}
           />

           <div className="mt-4 pt-4 border-t border-black/5 dark:border-white/5 animate-in slide-in-from-top-1">
              {isAdvancedMode ? (
                <AdvancedFilter 
                  type={type}
                  values={advancedFilters}
                  onChange={(key, val) => { setAdvancedFilters(prev => ({ ...prev, [key]: val })); setPage(0); }}
                />
              ) : (
                <DoubanFilter 
                  mode="secondary"
                  type={type}
                  activePrimary={activePrimary}
                  activeSecondary={activeSecondary}
                  onChange={(val) => { setActiveSecondary(val); setPage(0); }}
                />
              )}
           </div>
        </div>
      </header>

      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-10">
        {items.map((item, idx) => (
          <div key={`${item.id}-${idx}`} onClick={() => navigate(`/play?title=${encodeURIComponent(item.title)}&year=${item.year || ''}`)} className="cursor-pointer active-tactile">
             <MovieCard movie={{ 
               id: item.id, title: item.title, posterUrl: DoubanService.getImageUrl(item.cover), 
               rating: parseFloat(item.rate) || 0, releaseYear: parseInt(item.year || '2024'), category: title,
               description: '', backdropUrl: '', duration: ''
             }} />
          </div>
        ))}
        {loading && Array.from({length: 12}).map((_, i) => (
           <div key={i} className="aspect-[2/3] bg-black/5 dark:bg-white/5 rounded-[32px] animate-pulse" />
        ))}
      </div>

      {!loading && items.length > 0 && (
        <div className="py-20 flex justify-center">
           <ZenButton variant="secondary" className="px-10 h-14 rounded-full border border-white/20 shadow-sm" onClick={handleLoadMore}>
              加载更多
           </ZenButton>
        </div>
      )}
    </div>
  );
}
