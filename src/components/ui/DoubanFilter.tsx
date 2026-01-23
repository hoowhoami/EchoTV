import React from 'react';
import { cn } from '@/lib/utils';

interface FilterOption { label: string; value: string; }

interface DoubanFilterProps {
  mode: 'primary' | 'secondary';
  type: 'movie' | 'tv' | 'show' | 'anime';
  activePrimary: string;
  activeSecondary: string;
  onChange: (val: string) => void;
}

export const DoubanFilter = ({ mode, type, activePrimary, activeSecondary, onChange }: DoubanFilterProps) => {
  const options = {
    movie: {
      primary: [
        { label: '全部', value: '全部' },
        { label: '热门电影', value: '热门' },
        { label: '最新电影', value: '最新' },
        { label: '豆瓣高分', value: '豆瓣高分' },
        { label: '冷门佳片', value: '冷门佳片' },
      ],
      secondary: [
        { label: '全部', value: '全部' },
        { label: '华语', value: '华语' },
        { label: '欧美', value: '欧美' },
        { label: '韩国', value: '韩国' },
        { label: '日本', value: '日本' },
      ]
    },
    tv: {
      primary: [
        { label: '全部', value: '全部' },
        { label: '最近热门', value: '最近热门' },
      ],
      secondary: [
        { label: '全部', value: 'tv' },
        { label: '国产剧', value: 'tv_domestic' },
        { label: '美剧', value: 'tv_american' },
        { label: '日剧', value: 'tv_japanese' },
        { label: '韩剧', value: 'tv_korean' },
        { label: '动漫', value: 'tv_animation' },
        { label: '纪录片', value: 'tv_documentary' },
      ]
    },
    anime: {
      primary: [
        { label: '每日放送', value: '每日放送' },
        { label: '番剧', value: '番剧' },
        { label: '剧场版', value: '剧场版' },
      ],
      secondary: [
        { label: '全部', value: 'all' },
        { label: '周一', value: 'mon' },
        { label: '周二', value: 'tue' },
        { label: '周三', value: 'wed' },
        { label: '周四', value: 'thu' },
        { label: '周五', value: 'fri' },
        { label: '周六', value: 'sat' },
        { label: '周日', value: 'sun' },
      ]
    },
    show: {
      primary: [
        { label: '全部', value: '全部' },
        { label: '最近热门', value: '最近热门' },
      ],
      secondary: [
        { label: '全部', value: 'show' },
        { label: '国内', value: 'show_domestic' },
        { label: '国外', value: 'show_foreign' },
      ]
    }
  };

  const current = options[type];
  let list = current[mode];
  let label = mode === 'primary' ? '分类' : '地区';
  let activeValue = mode === 'primary' ? activePrimary : activeSecondary;

  // 联动逻辑：动漫在非“每日放送”模式下展示地区，而非星期
  if (type === 'anime' && mode === 'secondary' && activePrimary !== '每日放送') {
    label = '地区';
    list = [
      { label: '全部', value: '全部' },
      { label: '日本', value: '日本' },
      { label: '国产', value: '国产' },
    ];
  }

  // 联动逻辑：电视剧/综艺/动漫在一级非“全部”时，二级显示“类型”
  if ((type === 'tv' || type === 'show') && mode === 'secondary') {
    label = '类型';
  }

  return (
    <div className="flex items-center gap-4 py-1.5">
      <span className="text-[10px] font-black uppercase tracking-widest text-gray-400 whitespace-nowrap min-w-[45px] md:min-w-[50px]">
        {label}
      </span>
      <div className="flex-1 overflow-x-auto no-scrollbar">
        <div className="flex gap-1.5 p-1 bg-black/5 dark:bg-white/5 rounded-2xl w-max">
          {list.map(opt => (
            <button 
              key={opt.value} 
              onClick={() => onChange(opt.value)}
              className={cn(
                "px-4 py-1.5 rounded-xl text-[11px] font-bold transition-all whitespace-nowrap active-tactile",
                activeValue === opt.value 
                  ? "bg-white dark:bg-zinc-800 text-black dark:text-white shadow-sm" 
                  : "text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
              )}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};
