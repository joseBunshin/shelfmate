// Renders a book cover. When `coverUrl` is null/missing, falls back to a
// gradient placeholder with the book's initials — covers AE9 cover-fallback.
//
// The aspect ratio is 2:3 (standard book proportion). Width is controlled
// by the parent via class names.

type Props = {
  coverUrl: string | null;
  title: string;
  className?: string;
  priority?: boolean; // hint that this is above-the-fold
};

export function BookCover({ coverUrl, title, className = "", priority = false }: Props) {
  const initials = title
    .split(/\s+/)
    .filter((w) => w.length > 0 && /^[A-Za-z]/.test(w))
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join("");

  if (!coverUrl) {
    return (
      <div
        className={`relative aspect-[2/3] overflow-hidden rounded-lg bg-gradient-to-br from-zinc-700 via-zinc-800 to-zinc-950 shadow-lg ${className}`}
        aria-label={`${title} (no cover available)`}
      >
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-3xl font-semibold tracking-tight text-zinc-200">
            {initials || "B"}
          </span>
        </div>
        <div className="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-black/30 to-transparent" />
      </div>
    );
  }

  return (
    // Using a plain <img> intentionally — the cover URLs come from Supabase
    // Storage at runtime (R12) and the loader's domain set isn't fixed at
    // build time. Switch to next/image once the U4 storage bucket is wired
    // and we know the host pattern.
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={coverUrl}
      alt={`Cover of ${title}`}
      loading={priority ? "eager" : "lazy"}
      className={`aspect-[2/3] w-full rounded-lg object-cover shadow-lg ${className}`}
    />
  );
}
