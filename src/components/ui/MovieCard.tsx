import { Movie } from "@/types"
import { Play } from "lucide-react"
import { cn } from "@/lib/utils"

interface MovieCardProps {
  movie: Movie;
  className?: string;
}

export const MovieCard = ({ movie, className }: MovieCardProps) => {
  return (
    <div className={cn("group cursor-pointer active-tactile", className)}>
      <div className="relative aspect-[2/3] rounded-[28px] overflow-hidden bg-gray-200 border border-white/60 shadow-sm transition-all duration-500 group-hover:shadow-2xl group-hover:shadow-black/10 group-hover:-translate-y-1">
        {/* Dual-Stroke Border Simulator */}
        <div className="absolute inset-0 z-10 rounded-[28px] border border-gray-200/40 pointer-events-none" />
        
        <img 
          src={movie.posterUrl} 
          alt={movie.title}
          className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
        />
        
        {/* Hover Overlay */}
        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center backdrop-blur-[2px]">
          <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-xl scale-75 group-hover:scale-100 transition-transform duration-300">
            <Play size={20} fill="black" />
          </div>
        </div>
        
        {/* Rating Badge */}
        <div className="absolute top-4 right-4 z-20 px-2 py-1 bg-black/60 backdrop-blur-md rounded-lg border border-white/10">
          <span className="text-[10px] font-black text-white">{movie.rating.toFixed(1)}</span>
        </div>
      </div>
      
      <div className="mt-3 px-1">
        <h4 className="text-sm font-bold tracking-tight text-[#1C1C1E] line-clamp-1">{movie.title}</h4>
        <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-1">
          {movie.releaseYear} • {movie.category}
        </p>
      </div>
    </div>
  )
}
