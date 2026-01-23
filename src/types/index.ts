export interface Movie {
  id: string;
  title: string;
  description: string;
  posterUrl: string;
  backdropUrl: string;
  rating: number;
  releaseYear: number;
  duration: string;
  category: string;
  isTrending?: boolean;
}

export interface PlaySource {
  name: string;
  episodes: string[];
  episodes_titles: string[];
}

export interface SearchResult {
  id: string;
  title: string;
  poster: string;
  episodes: string[];
  episodes_titles: string[];
  play_sources?: PlaySource[];
  source: string;
  source_name: string;
  class?: string;
  year: string;
  desc?: string;
  type_name?: string;
  douban_id?: number;
}

export interface PlayRecord {
  title: string;
  source: string;
  cover: string;
  year: string;
  episode_index: number;
  episode_title: string;
  play_time: number;
  total_time: number;
  save_time: number;
}

export type Category = 'Movies' | 'Series' | 'Anime' | 'Documentary';