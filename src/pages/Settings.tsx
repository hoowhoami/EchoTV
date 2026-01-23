import { useState, useEffect } from 'react';
import { Plus, Globe, Settings as SettingsIcon, Trash2, ShieldCheck, Edit3, X, Tv, Code, FolderOpen, FileText, Database } from 'lucide-react';
import { ZenButton } from '@/components/ui/ZenButton';
import { storage, STORAGE_KEYS } from '@/lib/storage';
import { SubscriptionService } from '@/lib/subscription';
import { AppConfig, SiteConfig, LiveSource, CustomCategory } from '@/types/config';
import { DEFAULT_SITES } from '@/lib/api';
import { cn } from '@/lib/utils';

export default function SettingsPage() {
  const getInitialConfig = (): AppConfig => {
    const saved = storage.get<AppConfig>(STORAGE_KEYS.SETTINGS, null);
    if (saved && Array.isArray(saved.sites)) return saved;
    return {
      sites: DEFAULT_SITES,
      live_configs: [],
      categories: [],
      cache_time: 7200,
      site_name: 'MixTV'
    };
  };

  const [config, setConfig] = useState<AppConfig>(getInitialConfig);
  const [activeTab, setActiveTab] = useState<'general' | 'config_file' | 'sites' | 'lives' | 'categories'>('general');
  
  // 代理相关状态
  const [apiProxy, setApiProxy] = useState(() => storage.get(STORAGE_KEYS.PROXY, ''));
  const [doubanProxyType, setDoubanProxyType] = useState(() => storage.get(STORAGE_KEYS.DOUBAN_PROXY_TYPE, 'tencent-cmlius'));
  const [doubanProxyUrl, setDoubanProxyUrl] = useState(() => storage.get(STORAGE_KEYS.DOUBAN_PROXY, ''));

  const [subUrl, setSubUrl] = useState('');
  const [isSyncing, setIsSyncing] = useState(false);
  const [jsonContent, setJsonContent] = useState('');
  const [jsonError, setJsonError] = useState<string | null>(null);

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalType, setModalType] = useState<'site' | 'live' | 'category'>('site');
  const [editingItem, setEditingItem] = useState<any>({});

  useEffect(() => {
    setJsonContent(SubscriptionService.exportConfig(config));
  }, [config]);

  const saveConfig = (newConfig: AppConfig) => {
    setConfig(newConfig);
    storage.set(STORAGE_KEYS.SETTINGS, newConfig);
  };

  const handleJsonSave = () => {
    try {
      const parsed = SubscriptionService.parseConfig(jsonContent);
      saveConfig(parsed);
      setJsonError(null);
      alert('配置已应用');
    } catch (e: any) {
      setJsonError(e.message);
    }
  };

  const handleSyncSub = async () => {
    if (!subUrl.trim()) return;
    setIsSyncing(true);
    try {
      const newConfig = await SubscriptionService.fetchSubscription(subUrl);
      saveConfig(newConfig);
      alert('配置同步成功！');
    } catch (e) { alert('同步失败'); }
    finally { setIsSyncing(false); }
  };

  const openModal = (type: 'site' | 'live' | 'category', item: any = {}) => {
    setModalType(type);
    setEditingItem(item);
    setIsModalOpen(true);
  };

  const handleModalSave = () => {
    if (modalType === 'site') {
      const sites = [...(config.sites || [])];
      const idx = sites.findIndex(s => s.key === editingItem.key);
      if (idx > -1) sites[idx] = { ...editingItem, from: 'custom' };
      else sites.push({ ...editingItem, from: 'custom' });
      saveConfig({ ...config, sites });
    } else if (modalType === 'live') {
      const live_configs = [...(config.live_configs || [])];
      const idx = live_configs.findIndex(l => l.url === editingItem.url);
      if (idx > -1) live_configs[idx] = { ...editingItem, from: 'custom' };
      else live_configs.push({ ...editingItem, from: 'custom' });
      saveConfig({ ...config, live_configs });
    } else if (modalType === 'category') {
      const categories = [...(config.categories || [])];
      const idx = categories.findIndex(c => c.query === editingItem.query && c.type === editingItem.type);
      if (idx > -1) categories[idx] = { ...editingItem, from: 'custom' };
      else categories.push({ ...editingItem, from: 'custom' });
      saveConfig({ ...config, categories });
    }
    setIsModalOpen(false);
  };

  const tabs = [
    { id: 'general', label: '通用', icon: SettingsIcon },
    { id: 'config_file', label: '配置', icon: FileText },
    { id: 'sites', label: '视频源', icon: Globe },
    { id: 'lives', label: '直播源', icon: Tv },
    { id: 'categories', label: '分类', icon: FolderOpen },
  ];

  return (
    <div className="max-w-6xl mx-auto flex flex-col lg:flex-row gap-8 px-6 pb-32">
      <aside className="w-full lg:w-64 space-y-2">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={cn(
              "w-full flex items-center gap-4 px-6 py-4 rounded-2xl font-bold text-sm transition-all active-tactile",
              activeTab === tab.id 
                ? "bg-black text-white dark:bg-white dark:text-black shadow-lg" 
                : "bg-white/40 dark:bg-zinc-900/40 text-gray-500 hover:bg-white/60"
            )}
          >
            <tab.icon size={18} />
            {tab.label}
          </button>
        ))}
      </aside>

      <main className="flex-1 space-y-8 animate-in fade-in slide-in-from-right-4 duration-500">
        {activeTab === 'general' && (
          <div className="space-y-8">
            {/* 1. 豆瓣专用代理 */}
            <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[32px] p-8 border border-white/20 shadow-sm">
               <div className="flex items-center gap-3 mb-6">
                  <Database size={18} className="text-gray-400" />
                  <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400">豆瓣数据源 (专用)</h3>
               </div>
               <div className="space-y-4">
                  <div className="flex gap-1 p-1 bg-black/5 dark:bg-white/5 rounded-2xl">
                    {['tencent-cmlius', 'aliyun-cmlius', 'custom', 'none'].map(t => (
                      <button 
                        key={t} onClick={() => { setDoubanProxyType(t); storage.set(STORAGE_KEYS.DOUBAN_PROXY_TYPE, t); }}
                        className={`flex-1 py-3 rounded-xl text-[9px] font-black uppercase transition-all ${doubanProxyType === t ? 'bg-white dark:bg-zinc-800 text-black dark:text-white shadow-sm' : 'text-gray-400 hover:text-gray-600'}`}
                      >
                        {t === 'custom' ? '自定义' : t.split('-')[0]}
                      </button>
                    ))}
                  </div>
                  {doubanProxyType === 'custom' && (
                    <input 
                      type="text" placeholder="自定义豆瓣代理 URL"
                      className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 text-xs font-mono outline-none"
                      value={doubanProxyUrl} 
                      onChange={(e) => { setDoubanProxyUrl(e.target.value); storage.set(STORAGE_KEYS.DOUBAN_PROXY, e.target.value); }}
                    />
                  )}
                  <p className="text-[10px] text-gray-400 font-bold px-2 italic">仅用于解析豆瓣 Rexxar 接口及封面图。</p>
               </div>
            </section>

            {/* 2. 通用 API 代理 */}
            <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[32px] p-8 border border-white/20 shadow-sm">
               <div className="flex items-center gap-3 mb-6">
                  <ShieldCheck size={18} className="text-gray-400" />
                  <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400">视频源代理 (CORS 解除)</h3>
               </div>
               <div className="space-y-4">
                  <input 
                    type="text" placeholder="CORS 代理 URL (例如: https://proxy.workers.dev/?url=)"
                    className="w-full bg-black/5 dark:bg-white/5 border-2 border-transparent focus:bg-white dark:focus:bg-zinc-800 rounded-2xl py-4 px-6 text-xs font-mono outline-none"
                    value={apiProxy} 
                    onChange={(e) => { setApiProxy(e.target.value); storage.set(STORAGE_KEYS.PROXY, e.target.value); }}
                  />
                  <p className="text-[10px] text-gray-400 font-bold px-2 italic">用于解决部分采集站 API 在浏览器中的跨域拦截问题。留空则直连。</p>
               </div>
            </section>
          </div>
        )}

        {activeTab === 'config_file' && (
          <div className="space-y-8">
            <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[32px] p-8 border border-white/20 shadow-sm">
               <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400 mb-6">配置订阅</h3>
               <div className="flex gap-4">
                  <input 
                    type="text" placeholder="配置订阅地址 (JSON)"
                    className="flex-1 bg-black/5 dark:bg-white/5 border-2 border-transparent focus:bg-white dark:focus:bg-zinc-800 rounded-2xl py-4 px-6 text-sm font-bold outline-none"
                    value={subUrl} onChange={(e) => setSubUrl(e.target.value)}
                  />
                  <ZenButton className="px-8 rounded-2xl" onClick={handleSyncSub} disabled={isSyncing}>
                    {isSyncing ? '同步中...' : '拉取配置'}
                  </ZenButton>
               </div>
            </section>

            <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[40px] border border-white/20 shadow-sm p-8">
               <div className="flex items-center gap-3 mb-6">
                  <Code size={18} className="text-gray-400" />
                  <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400">直接编辑 JSON 内容</h3>
               </div>
               <textarea 
                  className={cn(
                    "w-full h-[400px] bg-black/5 dark:bg-zinc-800/40 rounded-[32px] p-8 font-mono text-xs outline-none border-2 transition-all resize-none leading-relaxed",
                    jsonError ? "border-red-500/50" : "border-transparent focus:border-black/10"
                  )}
                  value={jsonContent}
                  onChange={(e) => setJsonContent(e.target.value)}
                  spellCheck={false}
                />
                {jsonError && <p className="text-xs text-red-500 font-bold mt-4 px-4">{jsonError}</p>}
                <ZenButton variant="primary" className="w-full h-16 rounded-[24px] mt-6 text-base" onClick={handleJsonSave}>
                  应用 JSON 配置
                </ZenButton>
            </section>
          </div>
        )}

        {activeTab === 'sites' && (
          <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[40px] border border-white/20 shadow-sm overflow-hidden">
             <div className="p-8 border-b border-black/5 dark:border-white/5 flex items-center justify-between">
                <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400">视频源管理</h3>
                <ZenButton variant="ghost" size="sm" className="h-10 w-10 p-0 rounded-full" onClick={() => openModal('site')}>
                   <Plus size={20} />
                </ZenButton>
             </div>
             <div className="divide-y divide-black/5 dark:divide-white/5">
                {(config.sites || []).map((site) => (
                  <div key={site.key} className="p-6 flex items-center justify-between group">
                     <div className="flex items-center gap-4 min-w-0">
                        <div className="w-12 h-12 rounded-2xl bg-black dark:bg-white text-white dark:text-black flex items-center justify-center font-black text-sm shrink-0">{site.name?.[0]?.toUpperCase()}</div>
                        <div className="min-w-0">
                           <div className="flex items-center gap-2">
                             <p className="font-bold text-sm truncate">{site.name}</p>
                             <span className="text-[8px] px-1.5 py-0.5 bg-black/5 dark:bg-white/10 rounded uppercase font-black">{site.from || 'custom'}</span>
                           </div>
                           <p className="text-[10px] font-mono text-gray-400 truncate mt-1">{site.api}</p>
                        </div>
                     </div>
                     <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <ZenButton variant="ghost" className="h-10 w-10 p-0 rounded-full" onClick={() => openModal('site', site)}><Edit3 size={16} /></ZenButton>
                        <ZenButton variant="ghost" className="h-10 w-10 p-0 rounded-full text-red-500" onClick={() => { if(confirm('删除站点？')) saveConfig({...config, sites: config.sites.filter(s => s.key !== site.key)}); }}><Trash2 size={16} /></ZenButton>
                     </div>
                  </div>
                ))}
             </div>
          </section>
        )}

        {activeTab === 'lives' && (
          <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[40px] border border-white/20 shadow-sm overflow-hidden">
             <div className="p-8 border-b border-black/5 dark:border-white/5 flex items-center justify-between">
                <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400">直播源管理</h3>
                <ZenButton variant="ghost" size="sm" className="h-10 w-10 p-0 rounded-full" onClick={() => openModal('live')}>
                   <Plus size={20} />
                </ZenButton>
             </div>
             <div className="divide-y divide-black/5 dark:divide-white/5">
                {(config.live_configs || []).map((live) => (
                  <div key={live.url} className="p-6 flex items-center justify-between group">
                     <div className="flex items-center gap-4 min-w-0">
                        <div className="w-12 h-12 rounded-2xl bg-red-500 text-white flex items-center justify-center font-black text-[10px] uppercase shrink-0">Live</div>
                        <div className="min-w-0">
                           <p className="font-bold text-sm truncate">{live.name}</p>
                           <p className="text-[10px] font-mono text-gray-400 truncate mt-1">{live.url}</p>
                        </div>
                     </div>
                     <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <ZenButton variant="ghost" className="h-10 w-10 p-0 rounded-full" onClick={() => openModal('live', live)}><Edit3 size={16} /></ZenButton>
                        <ZenButton variant="ghost" className="h-10 w-10 p-0 rounded-full text-red-500" onClick={() => { if(confirm('删除直播源？')) saveConfig({...config, live_configs: config.live_configs.filter(l => l.url !== live.url)}); }}><Trash2 size={16} /></ZenButton>
                     </div>
                  </div>
                ))}
             </div>
          </section>
        )}

        {activeTab === 'categories' && (
          <section className="bg-white/60 dark:bg-zinc-900/40 backdrop-blur-xl rounded-[40px] border border-white/20 shadow-sm overflow-hidden">
             <div className="p-8 border-b border-black/5 dark:border-white/5 flex items-center justify-between">
                <h3 className="font-black text-[10px] uppercase tracking-widest text-gray-400">自定义分类</h3>
                <ZenButton variant="ghost" size="sm" className="h-10 w-10 p-0 rounded-full" onClick={() => openModal('category')}>
                   <Plus size={20} />
                </ZenButton>
             </div>
             <div className="divide-y divide-black/5 dark:divide-white/5">
                {(config.categories || []).map((cat) => (
                  <div key={`${cat.query}-${cat.type}`} className="p-6 flex items-center justify-between group">
                     <div className="flex items-center gap-4 min-w-0">
                        <div className="w-12 h-12 rounded-2xl bg-blue-500 text-white flex items-center justify-center font-black text-[10px] uppercase shrink-0">{cat.type}</div>
                        <div className="min-w-0">
                           <p className="font-bold text-sm truncate">{cat.name}</p>
                           <p className="text-[10px] font-mono text-gray-400 truncate mt-1">Query: {cat.query}</p>
                        </div>
                     </div>
                     <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <ZenButton variant="ghost" className="h-10 w-10 p-0 rounded-full" onClick={() => openModal('category', cat)}><Edit3 size={16} /></ZenButton>
                        <ZenButton variant="ghost" className="h-10 w-10 p-0 rounded-full text-red-500" onClick={() => { if(confirm('删除分类？')) saveConfig({...config, categories: config.categories.filter(c => !(c.query === cat.query && c.type === cat.type))}); }}><Trash2 size={16} /></ZenButton>
                     </div>
                  </div>
                ))}
             </div>
          </section>
        )}
      </main>

      {isModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/40 backdrop-blur-md animate-in fade-in duration-200">
           <div className="w-full max-w-lg bg-white dark:bg-zinc-900 rounded-[48px] p-10 shadow-2xl border border-white/20">
              <div className="flex justify-between items-center mb-10">
                 <h3 className="text-2xl font-black tracking-tighter">编辑{modalType === 'site' ? '视频源' : modalType === 'live' ? '直播源' : '分类'}</h3>
                 <button className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-black/5 transition-colors" onClick={() => setIsModalOpen(false)}><X size={24} /></button>
              </div>
              <div className="space-y-6">
                 {modalType === 'site' && (
                    <>
                      <input type="text" placeholder="站点名称" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-bold text-sm outline-none border-2 border-transparent focus:border-black/5" value={editingItem.name || ''} onChange={e => setEditingItem({...editingItem, name: e.target.value})} />
                      <input type="text" placeholder="站点标识 (Key)" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-bold text-sm outline-none border-2 border-transparent focus:border-black/5" value={editingItem.key || ''} onChange={e => setEditingItem({...editingItem, key: e.target.value})} />
                      <input type="text" placeholder="API 地址" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-mono text-xs outline-none border-2 border-transparent focus:border-black/5" value={editingItem.api || ''} onChange={e => setEditingItem({...editingItem, api: e.target.value})} />
                    </>
                 )}
                 {modalType === 'live' && (
                    <>
                      <input type="text" placeholder="直播名称" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-bold text-sm outline-none border-2 border-transparent focus:border-black/5" value={editingItem.name || ''} onChange={e => setEditingItem({...editingItem, name: e.target.value})} />
                      <input type="text" placeholder="M3U 订阅地址" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-mono text-xs outline-none border-2 border-transparent focus:border-black/5" value={editingItem.url || ''} onChange={e => setEditingItem({...editingItem, url: e.target.value})} />
                      <input type="text" placeholder="自定义 UA (可选)" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-mono text-xs outline-none border-2 border-transparent focus:border-black/5" value={editingItem.ua || ''} onChange={e => setEditingItem({...editingItem, ua: e.target.value})} />
                    </>
                 )}
                 {modalType === 'category' && (
                    <>
                      <input type="text" placeholder="分类名称" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-bold text-sm outline-none border-2 border-transparent focus:border-black/5" value={editingItem.name || ''} onChange={e => setEditingItem({...editingItem, name: e.target.value})} />
                      <select className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-bold text-sm outline-none border-2 border-transparent focus:border-black/5" value={editingItem.type || 'movie'} onChange={e => setEditingItem({...editingItem, type: e.target.value})}>
                        <option value="movie">电影</option>
                        <option value="tv">电视剧</option>
                      </select>
                      <input type="text" placeholder="搜索关键词 (Query)" className="w-full bg-black/5 dark:bg-white/5 rounded-2xl py-4 px-6 font-bold text-sm outline-none border-2 border-transparent focus:border-black/5" value={editingItem.query || ''} onChange={e => setEditingItem({...editingItem, query: e.target.value})} />
                    </>
                 )}
                 <ZenButton variant="primary" className="w-full h-16 rounded-[24px] text-base mt-4" onClick={handleModalSave}>确认保存</ZenButton>
              </div>
           </div>
        </div>
      )}
    </div>
  );
}