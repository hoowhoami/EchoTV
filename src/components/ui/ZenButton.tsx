import * as React from "react"
import { cn } from "@/lib/utils"

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'glass' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
}

export const ZenButton = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'md', ...props }, ref) => {
    const variants = {
      primary: "bg-[#1C1C1E] text-white shadow-lg shadow-black/10 hover:bg-black",
      secondary: "bg-white text-[#1C1C1E] border border-gray-200/50 shadow-sm hover:bg-gray-50",
      glass: "bg-white/20 backdrop-blur-md text-white border border-white/20 hover:bg-white/30",
      ghost: "hover:bg-black/5 text-gray-600 hover:text-black",
    }
    
    const sizes = {
      sm: "px-4 py-2 text-xs rounded-xl",
      md: "px-6 py-3 text-sm rounded-2xl",
      lg: "px-8 py-4 text-base rounded-[20px]",
    }

    return (
      <button
        ref={ref}
        className={cn(
          "inline-flex items-center justify-center font-bold tracking-tight active-tactile transition-all duration-200 disabled:opacity-50",
          variants[variant],
          sizes[size],
          className
        )}
        {...props}
      />
    )
  }
)
