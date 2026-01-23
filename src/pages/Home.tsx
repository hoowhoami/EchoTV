import { RefreshCcw, Settings as SettingsIcon, ChevronRight } from 'lucide-react'
import { useNavigate, Link } from 'react-router-dom'
import { ZenButton } from '@/components/ui/ZenButton'
import { MovieCard } from '@/components/ui/MovieCard'
import { storage, STORAGE_KEYS } from '@/lib/storage'
import { DoubanService } from '@/lib/douban'
import { BangumiService } from '@/lib/bangumi'
import { DoubanSubject } from '@/types/config'
import { PlayRecord } from '@/types'
import { useEffect, useState, useMemo } from 'react'
import { ContinueWatching } from '@/components/ui/ContinueWatching'

interface HomeData {
  movies: DoubanSubject[];
  tvShows: DoubanSubject[];
  variety: DoubanSubject[];
  anime: DoubanSubject[];
}

export default function HomePage() {
  const navigate = useNavigate();
  const [history, setHistory] = useState<PlayRecord[]>([]);
  const [data, setData] = useState<HomeData>({ movies: [], tvShows: [], variety: [], anime: [] });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      setLoading(true);
      try {
        setHistory(storage.get<PlayRecord[]>(STORAGE_KEYS.HISTORY, []));
        
        const [movies, tvShows, variety, calendar] = await Promise.all([
          DoubanService.getRecommends('movie'),
          DoubanService.getRecommends('tv'),
          DoubanService.getRecommends('show'),
          BangumiService.getCalendar()
        ]);

        // 获取今日番剧
        const today = new Date();
        const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const currentWeekday = weekdays[today.getDay()];
        const todayAnimes = calendar.find(item => item.weekday.en === currentWeekday)?.items.map(item => ({
          id: item.id.toString(),
          title: item.name_cn || item.name,
          rate: item.rating?.score?.toFixed(1) || '0.0',
          cover: item.images?.large || '',
          url: '',
          year: item.air_date?.split('-')[0] || ''
        })) || [];

        setData({
          movies: movies.slice(0, 12),
          tvShows: tvShows.slice(0, 12),
          variety: variety.slice(0, 12),
          anime: todayAnimes.slice(0, 12)
        });

      } catch (e) { console.error(e); }
      setLoading(false);
    }
    loadData();
  }, []);

  const heroMovie = useMemo(() => data.movies[0], [data.movies]);

  const renderSection = (title: string, items: DoubanSubject[], type: string, link: string) => (
    <section key={type} className="animate-in fade-in slide-in-from-bottom-4 duration-700">
      <div className="flex justify-between items-end mb-8">
        <div className="space-y-1">
          <h2 className="text-3xl font-black tracking-tighter">{title}</h2>
          <div className="h-1 w-12 bg-black dark:bg-white rounded-full opacity-10" />
        </div>
        <Link to={link} className="group flex items-center gap-2 text-[10px] font-black uppercase text-gray-400 tracking-[0.2em] hover:text-black dark:hover:text-white transition-colors">
          查看全部
          <ChevronRight size={14} className="transition-transform group-hover:translate-x-1" />
        </Link>
      </div>
      
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-6 md:gap-10">
        {items.map((item) => (
          <MovieCardItem key={item.id} item={item} navigate={navigate} />
        ))}
      </div>
    </section>
  );

  return (
    <div className="px-6 md:px-12 space-y-24 max-w-[1600px] mx-auto pb-24">
      {/* 🎬 英雄展示位 */}
      <section className="relative w-full aspect-[4/5] md:aspect-[21/9] rounded-[48px] overflow-hidden shadow-[0_40px_80px_-20px_rgba(0,0,0,0.15)] dark:shadow-[0_40px_80px_-20px_rgba(0,0,0,0.4)] bg-gray-100 dark:bg-zinc-900 mt-6">
        {loading ? (
           <div className="w-full h-full animate-pulse flex items-center justify-center">
              <RefreshCcw className="animate-spin text-gray-400" size={32} />
           </div>
        ) : heroMovie ? (
          <>
            <img src={DoubanService.getImageUrl(heroMovie.cover)} className="w-full h-full object-cover scale-105 blur-[2px] opacity-90 dark:opacity-60" alt="" />
            <div className="absolute inset-0 bg-gradient-to-t from-background via-background/20 to-transparent" />
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center p-6 md:p-12">
              <span className="bg-white/20 backdrop-blur-md border border-white/20 px-4 py-1.5 rounded-full text-[10px] font-black text-white uppercase tracking-[0.3em] mb-6 animate-in fade-in zoom-in duration-1000">
                今日推荐
              </span>
              <h2 className="text-5xl md:text-8xl font-black text-white dark:text-zinc-100 mb-10 tracking-tighter leading-none drop-shadow-2xl max-w-4xl animate-in slide-in-from-bottom-8 duration-1000">
                {heroMovie.title}
              </h2>
              <ZenButton variant="primary" size="lg" className="px-16 h-16 rounded-full text-lg shadow-2xl hover:scale-105 transition-transform duration-500" onClick={() => navigate(`/play?title=${encodeURIComponent(heroMovie.title)}&year=${heroMovie.year || ''}`)}>
                立即播放
              </ZenButton>
            </div>
          </>
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center text-gray-400">
             <SettingsIcon size={48} className="mb-4 opacity-10" />
             <p className="font-bold text-xs uppercase tracking-widest">请在设置中配置视频源</p>
          </div>
        )}
      </section>

      {/* 🕒 正在观看 */}
      {history.length > 0 && (
        <div className="overflow-hidden py-4">
          <ContinueWatching records={history} />
        </div>
      )}

      {loading ? (
        <div className="space-y-24">
          {[1,2,3].map(s => (
            <div key={s} className="space-y-8 animate-pulse">
              <div className="h-10 w-48 bg-black/5 dark:bg-white/5 rounded-2xl" />
              <div className="grid grid-cols-2 sm:grid-cols-6 gap-10">
                {[1,2,3,4,5,6].map(i => <div key={i} className="aspect-[2/3] bg-black/5 dark:bg-white/5 rounded-[40px]" />)}
              </div>
            </div>
          ))}
        </div>
      ) : (
      <div className="space-y-24">
        {data.movies.length > 0 && renderSection("热门电影", data.movies, "movie", "/movies")}
        {data.tvShows.length > 0 && renderSection("热播剧集", data.tvShows, "tv", "/series")}
        {data.anime.length > 0 && renderSection("新番放送", data.anime, "anime", "/anime")}
        {data.variety.length > 0 && renderSection("热门综艺", data.variety, "show", "/variety")}
      </div>
      )}
    </div>
  )
}

const MovieCardItem = ({ item, navigate }: { item: DoubanSubject, navigate: any }) => (
  <div onClick={() => navigate(`/play?title=${encodeURIComponent(item.title)}&year=${item.year || ''}`)} className="cursor-pointer active-tactile">
     <MovieCard movie={{ 
       id: item.id, title: item.title, posterUrl: DoubanService.getImageUrl(item.cover), 
       rating: parseFloat(item.rate) || 0, releaseYear: parseInt(item.year || '2024'), category: '', 
       description: '', backdropUrl: '', duration: ''
     }} />
  </div>
);
