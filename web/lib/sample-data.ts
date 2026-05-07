// Sample data for the E10 landing pages prior to U7 wiring real Supabase
// queries. These shapes mirror what U2's data layer returns; swapping to
// real data is a matter of replacing the imports in each route.

export type SampleBook = {
  id: string;
  external_id: string;
  title: string;
  authors: string[];
  cover_storage_url: string | null;
  publication_year: number | null;
  description?: string | null;
};

export type SampleUser = {
  id: string;
  display_name: string;
  username: string | null;
  avatar_storage_path: string | null;
  bio: string | null;
};

export type SampleRecommendation = {
  id: string;
  sender: SampleUser;
  book: SampleBook;
  note: string;
  created_at: string;
};

export type SampleListItem = {
  book: SampleBook;
  position: number;
  note: string | null;
};

export type SampleList = {
  id: string;
  owner: SampleUser;
  title: string;
  description: string | null;
  visibility: "private" | "friends" | "public";
  cover_book: SampleBook | null;
  items: SampleListItem[];
  updated_at: string;
};

export const SAMPLE_BOOKS: Record<string, SampleBook> = {
  hail_mary: {
    id: "11111111-0000-0000-0000-aaaaaaaaaaaa",
    external_id: "openlibrary:OL27258142W",
    title: "Project Hail Mary",
    authors: ["Andy Weir"],
    cover_storage_url: null,
    publication_year: 2021,
    description:
      "Ryland Grace wakes up alone on a spaceship with no memory of how he got there. As the truth of his mission unfolds, he must confront an extinction-level threat to humanity — and find an unlikely ally in the empty reaches of space.",
  },
  pachinko: {
    id: "11111111-0000-0000-0000-bbbbbbbbbbbb",
    external_id: "openlibrary:OL19345987W",
    title: "Pachinko",
    authors: ["Min Jin Lee"],
    cover_storage_url: null,
    publication_year: 2017,
    description:
      "An epic four-generation saga of a Korean family in twentieth-century Japan, navigating love, sacrifice, and the slow accretion of history.",
  },
  klara: {
    id: "11111111-0000-0000-0000-cccccccccccc",
    external_id: "openlibrary:OL26308663W",
    title: "Klara and the Sun",
    authors: ["Kazuo Ishiguro"],
    cover_storage_url: null,
    publication_year: 2021,
    description:
      "Klara, an Artificial Friend with outstanding observational qualities, watches carefully the behavior of those who come into the store and of those who pass on the street outside.",
  },
  babel: {
    id: "11111111-0000-0000-0000-dddddddddddd",
    external_id: "openlibrary:OL26845834W",
    title: "Babel",
    authors: ["R. F. Kuang"],
    cover_storage_url: null,
    publication_year: 2022,
    description:
      "Oxford's Royal Institute of Translation — Babel — is the world's center for translation and silver-working. But for Robin Swift, an orphan from Canton, learning is bound up in betrayal.",
  },
  wayfarers: {
    id: "11111111-0000-0000-0000-eeeeeeeeeeee",
    external_id: "openlibrary:OL17068019W",
    title: "The Long Way to a Small, Angry Planet",
    authors: ["Becky Chambers"],
    cover_storage_url: null,
    publication_year: 2014,
    description:
      "When Rosemary joins the crew of the Wayfarer, all she really wants is a fresh start. But aboard a ramshackle tunneling ship, she gets so much more.",
  },
  piranesi: {
    id: "11111111-0000-0000-0000-ffffffffffff",
    external_id: "openlibrary:OL21010088W",
    title: "Piranesi",
    authors: ["Susanna Clarke"],
    cover_storage_url: null,
    publication_year: 2020,
    description:
      "Piranesi's house is no ordinary building: its rooms are infinite, its corridors endless, its walls are lined with thousands upon thousands of statues, each one different from all the others.",
  },
};

export const SAMPLE_USERS: Record<string, SampleUser> = {
  alice: {
    id: "11111111-1111-1111-1111-111111111111",
    display_name: "Alice Tan",
    username: "alicereads",
    avatar_storage_path: null,
    bio: "Reading my way through the 21st-century literary canon, slowly. Sci-fi for breakfast, lit-fic for dinner.",
  },
  bob: {
    id: "22222222-2222-2222-2222-222222222222",
    display_name: "Bob Tanaka",
    username: "btanaka",
    avatar_storage_path: null,
    bio: null,
  },
};

export const SAMPLE_REC: SampleRecommendation = {
  id: "rrrrrrrr-1111-2222-3333-444444444444",
  sender: SAMPLE_USERS.alice,
  book: SAMPLE_BOOKS.hail_mary,
  note: "I know we don't usually do sci-fi but trust me — read the first 50 pages and you'll be in. The structure is perfect and the friendship is unlike anything else I've read this year.",
  created_at: "2026-04-28T14:23:00Z",
};

export const SAMPLE_LIST: SampleList = {
  id: "llllllll-1111-2222-3333-444444444444",
  owner: SAMPLE_USERS.alice,
  title: "Books that gutted me in 2025",
  description:
    "The ones that made me put the book down and stare at the wall. Ranked by the length of the stare.",
  visibility: "public",
  cover_book: SAMPLE_BOOKS.pachinko,
  updated_at: "2026-04-15T10:00:00Z",
  items: [
    { book: SAMPLE_BOOKS.pachinko, position: 0, note: "Generations. The pacing is patient in a way I don't see anymore." },
    { book: SAMPLE_BOOKS.klara, position: 1, note: "Quiet, devastating. Read it in one sitting on a flight." },
    { book: SAMPLE_BOOKS.babel, position: 2, note: "Hated it for 100 pages then I got it." },
    { book: SAMPLE_BOOKS.piranesi, position: 3, note: null },
    { book: SAMPLE_BOOKS.hail_mary, position: 4, note: "Funny + sad in equal measure." },
    { book: SAMPLE_BOOKS.wayfarers, position: 5, note: "The crew. The crew." },
  ],
};

export const SAMPLE_PROFILE_FINISHED: SampleBook[] = [
  SAMPLE_BOOKS.hail_mary,
  SAMPLE_BOOKS.pachinko,
  SAMPLE_BOOKS.klara,
  SAMPLE_BOOKS.babel,
];
