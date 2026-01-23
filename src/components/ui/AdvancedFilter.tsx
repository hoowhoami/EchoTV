import React, { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { ChevronDown, Check } from 'lucide-react';
import { cn } from '@/lib/utils';

interface Option { label: string; value: string; }
interface Category { key: string; label: string; options: Option[]; }

interface AdvancedFilterProps {
  type: 'movie' | 'tv' | 'show' | 'anime';
  values: Record<string, string>;
  onChange: (key: string, value: string) => void;
}

export const AdvancedFilter = ({ type, values, onChange }: AdvancedFilterProps) => {
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [coords, setCoords] = useState({ top: 0, left: 0 });
  const containerRef = useRef<HTMLDivElement>(null);
  const buttonRefs = useRef<Record<string, HTMLButtonElement | null>>({});

  // 1. 类型映射 (从 LunaTV 源码完整移植)
  const getTypeOptions = () => {
    const base = [{ label: '全部', value: '' }];
    if (type === 'movie') return [...base, { label: '喜剧', value: '喜剧' }, { label: '爱情', value: '爱情' }, { label: '动作', value: '动作' }, { label: '科幻', value: '科幻' }, { label: '悬疑', value: '悬疑' }, { label: '犯罪', value: '犯罪' }, { label: '惊悚', value: '惊悚' }, { label: '冒险', value: '冒险' }, { label: '恐怖', value: '恐怖' }, { label: '剧情', value: '剧情' }];
    if (type === 'tv') return [...base, { label: '喜剧', value: '喜剧' }, { label: '爱情', value: '爱情' }, { label: '悬疑', value: '悬疑' }, { label: '武侠', value: '武侠' }, { label: '古装', value: '古装' }, { label: '犯罪', value: '犯罪' }, { label: '科幻', value: '科幻' }, { label: '家庭', value: '家庭' }, { label: '剧情', value: '剧情' }];
    if (type === 'show') return [...base, { label: '真人秀', value: '真人秀' }, { label: '脱口秀', value: '脱口秀' }, { label: '音乐', value: '音乐' }, { label: '美食', value: '美食' }];
    if (type === 'anime') return [...base, { label: '治愈', value: '治愈' }, { label: '热血', value: '热血' }, { label: '冒险', value: '冒险' }, { label: '科幻', value: '科幻' }, { label: '奇幻', value: '奇幻' }, { label: '日常', value: '日常' }];
    return base;
  };

  // 2. 地区映射 (移植 LunaTV)
  const getRegionOptions = () => [
    { label: '全部', value: '' }, { label: '中国大陆', value: '中国大陆' }, { label: '美国', value: '美国' }, { label: '香港', value: '香港' }, { label: '台湾', value: '台湾' }, { label: '日本', value: '日本' }, { label: '韩国', value: '韩国' }, { label: '英国', value: '英国' }, { label: '法国', value: '法国' }, { label: '德国', value: '德国' }, { label: '印度', value: '印度' }, { label: '泰国', value: '泰国' }
  ];

  // 3. 平台映射 (LunaTV 特有)
  const getPlatformOptions = () => [
    { label: '全部', value: '' }, 
    { label: '腾讯视频', value: '腾讯视频' }, 
    { label: '爱奇艺', value: '爱奇艺' }, 
    { label: '优酷', value: '优酷' }, 
    { label: 'Netflix', value: 'Netflix' }, 
    { label: 'HBO', value: 'HBO' }, 
    { label: 'Disney+', value: 'Disney+' }
  ];

  const categories: Category[] = [
    { key: 'type', label: '类型', options: getTypeOptions() },
    { key: 'region', label: '地区', options: getRegionOptions() },
    { 
      key: 'year', label: '年代', 
      options: [
        { label: '全部', value: '' }, 
        { label: '2025', value: '2025' }, 
        { label: '2024', value: '2024' }, 
        { label: '2023', value: '2023' }, 
        { label: '2020年代', value: '2020年代' }, 
        { label: '2010年代', value: '2010年代' }, 
        { label: '2000年代', value: '2000年代' }, 
        { label: '90年代', value: '90年代' }, 
        { label: '更早', value: '更早' }
      ] 
    },
    ...(type !== 'movie' ? [{ key: 'platform', label: '平台', options: getPlatformOptions() }] : []),
    { 
      key: 'sort', label: '排序', 
      options: [
        { label: '综合排序', value: 'T' }, { label: '近期热度', value: 'U' }, { label: '评分最高', value: 'S' }, { label: '最新上映', value: 'R' }
      ] 
    }
  ];

  const handleOpen = (key: string) => {
    if (activeKey === key) { setActiveKey(null); return; }
    const btn = buttonRefs.current[key];
    if (btn) {
      const rect = btn.getBoundingClientRect();
      setCoords({ top: rect.bottom + window.scrollY, left: rect.left + window.scrollX });
      setActiveKey(key);
    }
  };

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (activeKey && !containerRef.current?.contains(e.target as Node)) {
        const portal = document.getElementById('filter-portal-root');
        if (!portal?.contains(e.target as Node)) setActiveKey(null);
      }
    };
    window.addEventListener('mousedown', handleClick);
    return () => window.removeEventListener('mousedown', handleClick);
  }, [activeKey]);

  return (
    <div ref={containerRef} className="flex items-center gap-4 py-1.5 w-full">
      <span className="text-[10px] font-black uppercase tracking-widest text-gray-400 whitespace-nowrap min-w-[45px] md:min-w-[50px]">筛选</span>
      <div className="flex-1 overflow-x-auto no-scrollbar">
        <div className="flex gap-2 w-max pr-10">
          {categories.map((cat) => {
            const activeOption = cat.options.find(o => o.value === (values[cat.key] || '')) || cat.options[0];
            const isOpen = activeKey === cat.key;
            const isFiltering = values[cat.key] && values[cat.key] !== '' && values[cat.key] !== 'T';
            return (
              <div key={cat.key} className="shrink-0">
                <button ref={el => buttonRefs.current[cat.key] = el} onClick={() => handleOpen(cat.key)} className={cn("flex items-center gap-2 px-4 py-2 rounded-[18px] text-[11px] font-bold border transition-all", isFiltering ? "bg-black text-white border-black dark:bg-white dark:text-black shadow-md" : "bg-black/5 dark:bg-white/5 text-gray-500 border-transparent")}>
                  <span className="opacity-40">{cat.label}</span>
                  <span>{activeOption.label}</span>
                  <ChevronDown size={12} className={cn("transition-transform duration-300 opacity-40", isOpen && "rotate-180")} />
                </button>
              </div>
            );
          })}
        </div>
      </div>

      {activeKey && createPortal(
        <div id="filter-portal-root" className="fixed z-[999] animate-in zoom-in-95 duration-200" style={{ top: `${coords.top + 8}px`, left: `${Math.min(coords.left, window.innerWidth - 280)}px` }}>
          <div className="w-64 p-2 bg-white dark:bg-zinc-900 rounded-[28px] shadow-[0_32px_64px_-16px_rgba(0,0,0,0.3)] border border-black/5 dark:border-white/10">
            <div className="grid grid-cols-2 gap-1">
              {categories.find(c => c.key === activeKey)?.options.map(opt => (
                <button key={opt.value} onClick={() => { onChange(activeKey, opt.value); setActiveKey(null); }} className={cn("flex items-center justify-between px-4 py-3 rounded-xl text-[11px] font-bold transition-all", (values[activeKey] || '') === opt.value ? "bg-black text-white dark:bg-white dark:text-black shadow-md" : "hover:bg-black/5 dark:hover:bg-white/5 text-gray-500")}>
                  {opt.label}
                  {(values[activeKey] || '') === opt.value && <Check size={12} strokeWidth={3} />}
                </button>
              ))}
            </div>
          </div>
        </div>, document.body
      )}
    </div>
  );
};
