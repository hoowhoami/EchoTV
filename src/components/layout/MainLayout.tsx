import { useNavigate, useLocation, Outlet } from 'react-router-dom';
import { Search, Home, Tv, Settings, Moon, Sun, Film, Clapperboard, MonitorPlay, Ghost } from 'lucide-react';
import { ZenButton } from '@/components/ui/ZenButton';
import { useState, useEffect } from 'react';

export const MainLayout = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [isDark, setIsDark] = useState(() => document.documentElement.classList.contains('dark'));

  const toggleTheme = () => {
    const newDark = !isDark;
    setIsDark(newDark);
    document.documentElement.classList.toggle('dark', newDark);
    localStorage.setItem('theme', newDark ? 'dark' : 'light');
  };

  useEffect(() => {
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'dark') {
      document.documentElement.classList.add('dark');
      setIsDark(true);
    }
  }, []);

  const isPlayPage = location.pathname.startsWith('/play');

  // 移植 LunaTV 的完整导航项
  const navItems = [
    { path: '/', label: '首页', icon: Home },
    { path: '/movies', label: '电影', icon: Film },
    { path: '/series', label: '剧集', icon: Clapperboard },
    { path: '/anime', label: '动漫', icon: Ghost },
    { path: '/variety', label: '综艺', icon: MonitorPlay },
    { path: '/live', label: '直播', icon: Tv },
    { path: '/search', label: '搜索', icon: Search },
  ];

  return (
    <div className="min-h-screen">
      {/* 🛑 顶部栏 */}
      <nav className="fixed top-0 w-full z-50 px-6 py-4 flex items-center justify-between backdrop-blur-3xl bg-white/40 dark:bg-black/40 border-b border-white/20">
        <div className="flex items-center gap-2 cursor-pointer active-tactile" onClick={() => navigate('/')}>
          <div className="w-8 h-8 bg-black dark:bg-white rounded-lg flex items-center justify-center">
            <div className="w-4 h-4 bg-white dark:bg-black rounded-sm rotate-45" />
          </div>
          <h1 className="text-xl font-black tracking-tighter uppercase">MixTV</h1>
        </div>
        
        <div className="flex items-center gap-3">
          <ZenButton variant="ghost" size="sm" className="rounded-full w-10 h-10 p-0" onClick={toggleTheme}>
            {isDark ? <Sun size={20} /> : <Moon size={20} />}
          </ZenButton>
          <ZenButton variant="ghost" size="sm" className="rounded-full w-10 h-10 p-0" onClick={() => navigate('/settings')}>
            <Settings size={20} />
          </ZenButton>
        </div>
      </nav>

      {/* 🎬 内容区 */}
      <main className="pt-24 pb-32">
        <div className="animate-in fade-in duration-500">
          <Outlet />
        </div>
      </main>

      {/* 🛑 底部悬浮导航：完整功能版 */}
      <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-1 p-1 glass-morphism rounded-full shadow-2xl max-w-[95vw] overflow-x-auto no-scrollbar">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          return (
            <button
              key={item.path}
              onClick={() => navigate(item.path)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-full transition-all duration-300 active:scale-90 shrink-0 ${
                isActive 
                ? 'bg-black text-white dark:bg-white dark:text-black shadow-lg' 
                : 'text-gray-500 hover:bg-black/5 dark:hover:bg-white/5'
              }`}
            >
              <item.icon size={18} strokeWidth={isActive ? 2.5 : 2} />
              <span className={`text-[11px] font-bold ${isActive ? 'block' : 'hidden lg:block'}`}>
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
};