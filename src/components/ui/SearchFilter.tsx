import { cn } from "@/lib/utils";

interface FilterOption {
  label: string;
  value: string;
}

interface SearchFilterProps {
  label: string;
  options: FilterOption[];
  activeValue: string;
  onChange: (value: string) => void;
}

export const SearchFilter = ({ label, options, activeValue, onChange }: SearchFilterProps) => {
  return (
    <div className="flex items-center gap-4 py-2 overflow-x-auto no-scrollbar">
      <span className="text-[10px] font-black uppercase tracking-widest text-gray-400 whitespace-nowrap min-w-[60px]">
        {label}
      </span>
      <div className="flex gap-2">
        {options.map((opt) => (
          <button
            key={opt.value}
            onClick={() => onChange(opt.value)}
            className={cn(
              "px-4 py-1.5 rounded-full text-xs font-bold transition-all whitespace-nowrap active-tactile",
              activeValue === opt.value
                ? "bg-black text-white shadow-md shadow-black/10"
                : "bg-white/60 text-gray-500 hover:bg-white border border-transparent hover:border-black/5"
            )}
          >
            {opt.label}
          </button>
        ))}
      </div>
    </div>
  );
};
