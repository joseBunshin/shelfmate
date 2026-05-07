// E10-001 Direct Rec Landing.
//
// Layout matches AE5: above-fold render within 2s on LTE = book cover +
// sender display name + first line of note + primary CTA. Description
// continues below the fold; secondary CTAs at the bottom.
//
// SAMPLE DATA: U7 will replace `lookupRec` with a Supabase anon-role
// query for `recommendations` joined to `books` and `users`. The shape
// of SampleRecommendation already mirrors that join.

import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { BookCover } from "@/components/BookCover";
import { MarketingShell } from "@/components/MarketingShell";
import { StoreBadges } from "@/components/StoreBadges";
import { detectPlatform } from "@/lib/branch";
import { SAMPLE_REC, type SampleRecommendation } from "@/lib/sample-data";

export const runtime = "edge";

type Props = {
  params: Promise<{ recId: string }>;
};

async function lookupRec(recId: string): Promise<SampleRecommendation | null> {
  // U7 replacement: query Supabase anon-role for the rec by id, join sender
  // user + book metadata (server-side, edge-runtime supabase-js client).
  // For now the sample rec returns for any id ending in `sample` or for
  // the canonical sample id, so the page works for both /rec/sample and
  // the deep-linked uuid form.
  if (recId === SAMPLE_REC.id || recId.endsWith("sample")) return SAMPLE_REC;
  return null;
}

export default async function RecLandingPage({ params }: Props) {
  const { recId } = await params;
  const rec = await lookupRec(recId);
  if (!rec) notFound();

  const ua = (await headers()).get("user-agent");
  const platform = detectPlatform(ua);
  const senderFirstName = rec.sender.display_name.split(" ")[0]!;

  return (
    <MarketingShell bareHeader>
      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col px-6 pb-16 pt-4">
        <p className="mb-3 text-xs uppercase tracking-wider text-zinc-500 dark:text-zinc-400">
          {senderFirstName} sent you a book
        </p>

        <section className="grid gap-8 sm:grid-cols-[180px_1fr] sm:items-start">
          <div className="mx-auto w-full max-w-[180px] sm:mx-0">
            <BookCover coverUrl={rec.book.cover_storage_url} title={rec.book.title} priority />
          </div>

          <div className="flex flex-col gap-3">
            <h1 className="text-balance text-3xl font-semibold tracking-tight text-zinc-900 sm:text-4xl dark:text-zinc-50">
              {rec.book.title}
            </h1>
            <p className="text-base text-zinc-600 dark:text-zinc-400">
              by {rec.book.authors.join(", ")}
              {rec.book.publication_year ? ` · ${rec.book.publication_year}` : ""}
            </p>

            <figure className="mt-3 rounded-xl border border-zinc-200 bg-zinc-50 p-5 dark:border-zinc-800 dark:bg-zinc-900">
              <blockquote className="text-base leading-relaxed text-zinc-800 dark:text-zinc-200">
                &ldquo;{rec.note}&rdquo;
              </blockquote>
              <figcaption className="mt-3 text-sm text-zinc-600 dark:text-zinc-400">
                — {rec.sender.display_name}
              </figcaption>
            </figure>
          </div>
        </section>

        <section className="mt-10 flex flex-col items-center gap-3 text-center">
          <StoreBadges
            detectedPlatform={platform}
            fromUserId={rec.sender.id}
            fromRecId={rec.id}
          />
          <p className="text-xs text-zinc-500 dark:text-zinc-500">
            Open in ShelfMate to add to your reading list and reply to {senderFirstName}.
          </p>
        </section>

        {rec.book.description && (
          <section className="mt-12 max-w-prose self-center">
            <h2 className="mb-2 text-sm font-semibold uppercase tracking-wider text-zinc-500 dark:text-zinc-400">
              About the book
            </h2>
            <p className="text-base leading-relaxed text-zinc-700 dark:text-zinc-300">
              {rec.book.description}
            </p>
          </section>
        )}
      </main>
    </MarketingShell>
  );
}
