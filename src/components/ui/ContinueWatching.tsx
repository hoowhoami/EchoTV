import { Play } from 'lucide-react';
import { PlayRecord } from '@/types';
import { useNavigate } from 'react-router-dom';

interface ContinueWatchingProps {
  records: PlayRecord[];
}

export const ContinueWatching = ({ records }: ContinueWatchingProps) => {
  const navigate = useNavigate();

  if (records.length === 0) return null;

  return (
    <section className="space-y-6">
      <div className="flex items-center gap-3">
        <div className="w-1.5 h-6 bg-black rounded-full" />
        <h2 className="text-2xl font-black tracking-tighter">Continue Watching</h2>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {records.slice(0, 3).map((record) => {
          const progress = (record.play_time / record.total_time) * 100;
          return (
            <div 
              key={record.save_time} 
              onClick={() => navigate(`/play?id=${record.title}&source=${record.source}`)}
              className="group relative bg-white/40 backdrop-blur-xl rounded-ios-xl border border-white/60 p-4 flex gap-5 items-center hover:bg-white/60 transition-all cursor-pointer active-tactile shadow-sm hover:shadow-xl hover:shadow-black/5"
            >
              <div className="relative w-36 aspect-video rounded-lg overflow-hidden bg-gray-200 flex-shrink-0 shadow-inner">
                <img src={record.cover} className="w-full h-full object-cover transition-transform group-hover:scale-105" />
                <div className="absolute inset-0 bg-black/20 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                   <Play size={24} fill="white" className="text-white" />
                </div>
                {/* Progress Bar */}
                <div className="absolute bottom-0 left-0 w-full h-1 bg-black/20">
                   <div className="h-full bg-red-600 shadow-[0_0_8px_rgba(220,38,38,0.5)]" style={{ width: `${progress}%` }} />
                </div>
              </div>
              <div className="flex-1 min-w-0">
                <h4 className="font-bold text-sm truncate text-[#1C1C1E]">{record.title}</h4>
                <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-1">
                  {record.episode_title}
                </p>
                <p className="text-[9px] font-black text-gray-300 mt-2 uppercase">
                  {Math.floor(record.play_time / 60)}m / {Math.floor(record.total_time / 60)}m
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
};
