import { useEffect, useRef } from 'react';
import Artplayer from 'artplayer';
import Hls from 'hls.js';
import { cn } from '@/lib/utils';

interface ZenPlayerProps {
  url: string;
  title?: string;
  poster?: string;
  onProgress?: (currentTime: number, totalTime: number) => void;
  className?: string;
}

export const ZenPlayer = ({ url, title, poster, onProgress, className }: ZenPlayerProps) => {
  const artRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!artRef.current) return;

    const art = new Artplayer({
      container: artRef.current,
      url: url,
      title: title,
      poster: poster,
      volume: 0.7,
      isLive: false,
      muted: false,
      autoplay: true,
      pip: true,
      autoSize: true,
      autoMini: true,
      screenshot: true,
      setting: true,
      loop: false,
      flip: true,
      playbackRate: true,
      aspectRatio: true,
      fullscreen: true,
      fullscreenWeb: true,
      subtitleOffset: true,
      miniProgressBar: true,
      mutex: true,
      backdrop: true,
      playsInline: true,
      autoPlayback: true,
      airplay: true,
      theme: '#1C1C1E', // 匹配我们的 Zen-iOS 黑色
      customType: {
        m3u8: function (video, url) {
          if (Hls.isSupported()) {
            const hls = new Hls();
            hls.loadSource(url);
            hls.attachMedia(video);
          } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = url;
          }
        },
      },
    });

    art.on('video:timeupdate', () => {
      onProgress?.(art.video.currentTime, art.video.duration);
    });

    return () => {
      if (art && art.destroy) {
        art.destroy(false);
      }
    };
  }, [url]);

  return (
    <div 
      ref={artRef} 
      className={cn(
        "relative w-full aspect-video rounded-ios-2xl overflow-hidden shadow-2xl border border-white/40",
        className
      )}
    />
  );
};
