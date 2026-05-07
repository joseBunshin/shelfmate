// E10-004 Public List landing.
//
// Layout: hero (list title + owner attribution + cover-book), grid of
// items with covers + titles + per-item notes, primary CTA at the
// bottom. R11: visibility flips trigger SSR cache invalidation in U7
// via pg_net trigger; for now rendering is on-demand.
//
// SAMPLE DATA: U7 replaces `lookupList` with a Supabase anon-role query
// for book_lists where visibility='public' joined to items + books +
// owner. The shape of SampleList mirrors that join.

import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { BookCover } from "@/components/BookCover";
import { MarketingShell } from "@/components/MarketingShell";
import { StoreBadges } from "@/components/StoreBadges";
import { detectPlatform } from "@/lib/branch";
import { SAMPLE_LIST, type SampleList } from "@/lib/sample-data";

export const runtime = "edge";

type Props = {
  params: Promise<{ listId: string }>;
};

async function lookupList(listId: string): Promise<SampleList | null> {
  if (listId === SAMPLE_LIST.id || listId.endsWith("sample")) return SAMPLE_LIST;
  return null;
}

export default async function PublicListPage({ params }: Props) {
  const { listId } = await params;
  const list = await lookupList(listId);
  if (!list) notFound();

  const ua = (await headers()).get("user-agent");
  const platform = detectPlatform(ua);

  return (
    <MarketingShell>
      <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col px-6 pb-16 pt-4">
        <section className="grid gap-8 sm:grid-cols-[160px_1fr] sm:items-end">
          {list.cover_book && (
            <div className="mx-auto w-full max-w-[160px] sm:mx-0">
              <BookCover coverUrl={list.cover_book.cover_storage_url} title={list.cover_book.title} priority />
            </div>
          )}
          <div className="flex flex-col gap-2">
            <p className="text-xs uppercase tracking-wider text-zinc-500 dark:text-zinc-400">
              A list by {list.owner.display_name}
            </p>
            <h1 className="text-balance text-3xl font-semibold tracking-tight text-zinc-900 sm:text-4xl dark:text-zinc-50">
              {list.title}
            </h1>
            {list.description && (
              <p className="max-w-prose text-base leading-relaxed text-zinc-600 dark:text-zinc-400">
                {list.description}
              </p>
            )}
            <p className="text-sm text-zinc-500 dark:text-zinc-500">{list.items.length} books</p>
          </div>
        </section>

        <section className="mt-12">
          <ul className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {list.items.map(({ book, note, position }) => (
              <li key={book.id} className="flex flex-col gap-3">
                <div className="flex gap-4">
                  <div className="w-20 shrink-0">
                    <BookCover coverUrl={book.cover_storage_url} title={book.title} />
                  </div>
                  <div className="flex flex-col gap-1">
                    <p className="text-xs text-zinc-400 dark:text-zinc-500">#{position + 1}</p>
                    <h3 className="text-base font-semibold leading-tight text-zinc-900 dark:text-zinc-50">
                      {book.title}
                    </h3>
                    <p className="text-sm text-zinc-600 dark:text-zinc-400">
                      {book.authors.join(", ")}
                    </p>
                  </div>
                </div>
                {note && (
                  <p className="text-sm leading-relaxed text-zinc-700 dark:text-zinc-300">
                    &ldquo;{note}&rdquo;
                  </p>
                )}
              </li>
            ))}
          </ul>
        </section>

        <section className="mt-16 flex flex-col items-center gap-3 text-center">
          <StoreBadges detectedPlatform={platform} fromUserId={list.owner.id} />
          <p className="text-xs text-zinc-500 dark:text-zinc-500">
            See more from {list.owner.display_name} in the ShelfMate app.
          </p>
        </section>
      </main>
    </MarketingShell>
  );
}
