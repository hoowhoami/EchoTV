import { Movie } from "@/types";

export const MOCK_MOVIES: Movie[] = [
  {
    id: '1',
    title: 'Interstellar',
    description: 'A team of explorers travel through a wormhole in space in an attempt to ensure humanity\'s survival.',
    posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=1000',
    backdropUrl: 'https://images.unsplash.com/photo-1626814026160-2237a95fc5a0?q=80&w=2070',
    rating: 8.7,
    releaseYear: 2014,
    duration: '2h 49m',
    category: 'Sci-Fi',
    isTrending: true
  },
  {
    id: '2',
    title: 'Inception',
    description: 'A thief who steals corporate secrets through the use of dream-sharing technology.',
    posterUrl: 'https://images.unsplash.com/photo-1614850523296-d8c1af93d400?q=80&w=1000',
    backdropUrl: 'https://images.unsplash.com/photo-1500673922987-e212871fec22?q=80&w=2070',
    rating: 8.8,
    releaseYear: 2010,
    duration: '2h 28m',
    category: 'Action',
    isTrending: true
  },
  {
    id: '3',
    title: 'The Dark Knight',
    description: 'When the menace known as the Joker wreaks havoc and chaos on the people of Gotham.',
    posterUrl: 'https://images.unsplash.com/photo-1478720568477-152d9b164e26?q=80&w=1000',
    backdropUrl: 'https://images.unsplash.com/photo-1531259683007-016a7b628fc3?q=80&w=2070',
    rating: 9.0,
    releaseYear: 2008,
    duration: '2h 32m',
    category: 'Crime',
    isTrending: false
  },
  {
    id: '4',
    title: 'Dune: Part Two',
    description: 'Paul Atreides unites with Chani and the Fremen while on a warpath of revenge.',
    posterUrl: 'https://images.unsplash.com/photo-1509347528160-9a9e33742cdb?q=80&w=1000',
    backdropUrl: 'https://images.unsplash.com/photo-1533613220915-609f661a6fe1?q=80&w=2070',
    rating: 8.9,
    releaseYear: 2024,
    duration: '2h 46m',
    category: 'Sci-Fi',
    isTrending: true
  },
  {
    id: '5',
    title: 'Blade Runner 2049',
    description: 'A young Blade Runner\'s discovery of a long-buried secret leads him to track down Rick Deckard.',
    posterUrl: 'https://images.unsplash.com/photo-1485846234645-a62644f84728?q=80&w=1000',
    backdropUrl: 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?q=80&w=2070',
    rating: 8.0,
    releaseYear: 2017,
    duration: '2h 44m',
    category: 'Sci-Fi',
    isTrending: false
  },
  {
    id: '6',
    title: 'Oppenheimer',
    description: 'The story of American scientist J. Robert Oppenheimer and his role in the development of the atomic bomb.',
    posterUrl: 'https://images.unsplash.com/photo-1440404653325-ab127d49abc1?q=80&w=1000',
    backdropUrl: 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?q=80&w=2070',
    rating: 8.4,
    releaseYear: 2023,
    duration: '3h 0m',
    category: 'Drama',
    isTrending: true
  }
];
