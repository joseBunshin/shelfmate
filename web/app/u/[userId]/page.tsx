// E10-002 Social Discovery + E10-003 Inviter Profile.
//
// Same route serves both contexts; content is identical (display name +
// bio + recent reads). Future U7 work could split inviter-context (with
// "you were invited by" framing) from cold-discovery (no framing) but
// the shape is the same.
//
// SAMPLE DATA: U7 replaces lookupProfile with a Supabase anon-role query
// for users + profiles + recent user_books where status='read' and the
// owner's writer_setting allows everyone.

import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { BookCover } from "@/components/BookCover";
import { MarketingShell } from "@/components/MarketingShell";
import { StoreBadges } from "@/components/StoreBadges";
import { detectPlatform } from "@/lib/branch";
import {
  SAMPLE_PROFILE_FINISHED,
  SAMPLE_USERS,
  type SampleBook,
  type SampleUser,
} from "@/lib/sample-data";

export const runtime = "edge";

type Props = {
  params: Promise<{ userId: string }>;
};

type Resolved = { user: SampleUser; recentlyRead: SampleBook[] } | null;

async function lookupProfile(userId: string): Promise<Resolved> {
  if (userId === SAMPLE_USERS.alice.id || userId.endsWith("sample")) {
    return { user: SAMPLE_USERS.alice, recentlyRead: SAMPLE_PROFILE_FINISHED };
  }
  return null;
}

export default async function ProfilePage({ params }: Props) {
  const { userId } = await params;
  const resolved = await lookupProfile(userId);
  if (!resolved) notFound();

  const { user, recentlyRead } = resolved;
  const ua = (await headers()).get("user-agent");
  const platform = detectPlatform(ua);
  const initials = user.display_name
    .split(/\s+/)
    .map((w) => w[0]!.toUpperCase())
    .slice(0, 2)
    .join("");

  return (
    <MarketingShell>
      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col px-6 pb-16 pt-4">
        <section className="flex flex-col items-center gap-4 text-center">
          <div className="flex h-24 w-24 items-center justify-center rounded-full bg-gradient-to-br from-indigo-400 to-rose-400 text-3xl font-semibold text-white shadow-lg">
            {initials}
          </div>
          <div>
            <h1 className="text-3xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-50">
              {user.display_name}
            </h1>
            {user.username && (
              <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">@{user.username}</p>
            )}
          </div>
          {user.bio && (
            <p className="max-w-prose text-balance text-base text-zinc-600 dark:text-zinc-400">
              {user.bio}
            </p>
          )}
        </section>

        {recentlyRead.length > 0 && (
          <section className="mt-12">
            <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-zinc-500 dark:text-zinc-400">
              Recently finished
            </h2>
            <ul className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              {recentlyRead.slice(0, 4).map((book) => (
                <li key={book.id} className="flex flex-col gap-2">
                  <BookCover coverUrl={book.cover_storage_url} title={book.title} />
                  <div>
                    <p className="text-sm font-medium leading-tight text-zinc-900 dark:text-zinc-50">
                      {book.title}
                    </p>
                    <p className="text-xs text-zinc-500 dark:text-zinc-400">
                      {book.authors.join(", ")}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </section>
        )}

        <section className="mt-16 flex flex-col items-center gap-3 text-center">
          <StoreBadges detectedPlatform={platform} fromUserId={user.id} />
          <p className="text-xs text-zinc-500 dark:text-zinc-500">
            ShelfMate is a closed-friend-graph book tracker. Add {user.display_name.split(" ")[0]} after you sign up.
          </p>
        </section>
      </main>
    </MarketingShell>
  );
}
