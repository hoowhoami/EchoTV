import { BrowserRouter, Routes, Route } from 'react-router-dom';
import HomePage from './pages/Home';
import PlayPage from './pages/Play';
import SearchPage from './pages/Search';
import SettingsPage from './pages/Settings';
import LivePage from './pages/Live';
import ExplorePage from './pages/Explore';
import { MainLayout } from './components/layout/MainLayout';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<MainLayout />}>
          <Route path="/" element={<HomePage />} />
          
          {/* 完美的 LunaTV 分类映射逻辑 */}
          <Route path="/movies" element={<ExplorePage title="电影" type="movie" />} />
          <Route path="/series" element={<ExplorePage title="剧集" type="tv" />} />
          <Route path="/anime" element={<ExplorePage title="动漫" type="anime" />} />
          <Route path="/variety" element={<ExplorePage title="综艺" type="show" />} />
          
          <Route path="/search" element={<SearchPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/live" element={<LivePage />} />
          <Route path="/play" element={<PlayPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;