import { useState, useEffect } from 'react';
import { storage, STORAGE_KEYS } from '@/lib/storage';
import { DEFAULT_SITES, ApiSite } from '@/lib/api';

export function useSettings() {
  const [sites, setSites] = useState<ApiSite[]>([]);
  const [activeSite, setActiveSite] = useState<ApiSite | null>(null);

  useEffect(() => {
    const savedSites = storage.get<ApiSite[]>(STORAGE_KEYS.SOURCES, DEFAULT_SITES);
    setSites(savedSites);
    setActiveSite(savedSites[0] || null);
  }, []);

  const addSite = (site: ApiSite) => {
    const newSites = [...sites, site];
    setSites(newSites);
    storage.set(STORAGE_KEYS.SOURCES, newSites);
  };

  const removeSite = (key: string) => {
    const newSites = sites.filter(s => s.key !== key);
    setSites(newSites);
    storage.set(STORAGE_KEYS.SOURCES, newSites);
  };

  return {
    sites,
    activeSite,
    setActiveSite,
    addSite,
    removeSite,
  };
}
