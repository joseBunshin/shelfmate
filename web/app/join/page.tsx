// E10-005 Join ShelfMate landing.
//
// Reads UA via headers, detects platform, renders a single primary CTA
// for the matched store (iOS or Android) plus a secondary fallback for
// the other. Unknown UA shows both badges side-by-side.
//
// U7 replacement: the App Store / Play Store hrefs become real Branch
// deferred-deep-link URLs that carry the from_user_id and from_rec_id
// params through the install boundary (R13/R14). Right now these route
// to placeholder /apple and /android paths so we can demo the platform
// detection without leaking real store URLs.

import { headers } from "next/headers";
import Link from "next/link";
import { MarketingShell } from "@/components/MarketingShell";
import { detectPlatform, type AppStorePlatform } from "@/lib/branch";

export const runtime = "edge";

type Props = {
  searchParams: Promise<{
    from_user_id?: string;
    from_rec_id?: string;
  }>;
};

export default async function JoinPage({ searchParams }: Props) {
  const params = await searchParams;
  const ua = (await headers()).get("user-agent");
  const platform = detectPlatform(ua);

  const fromUserId = params.from_user_id;
  const fromRecId = params.from_rec_id;
  const headline = fromRecId
    ? "Get ShelfMate to open this rec"
    : fromUserId
      ? "Get ShelfMate to add your friend"
      : "Track books with the people you actually know";

  return (
    <MarketingShell>
      <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col items-center justify-center gap-8 px-6 py-16 text-center">
        <h1 className="text-balance text-3xl font-semibold tracking-tight text-zinc-900 sm:text-4xl dark:text-zinc-50">
          {headline}
        </h1>
        <p className="max-w-md text-balance text-base text-zinc-600 dark:text-zinc-400">
          Personal book tracking, friend-only sharing, and recs from people whose
          taste you actually trust. iOS + Android.
        </p>

        <div className="flex flex-col items-stretch gap-3 sm:items-center">
          <PrimaryStoreCTA platform={platform} />
          <FallbackHint platform={platform} />
        </div>

        <p className="text-xs text-zinc-500 dark:text-zinc-500">
          {fromRecId || fromUserId
            ? "We'll pick up where the link left off after you install."
            : "No public feed. No follower count. No strangers."}
        </p>
      </main>
    </MarketingShell>
  );
}

function PrimaryStoreCTA({ platform }: { platform: AppStorePlatform }) {
  if (platform === "ios") {
    return <BigBadge platform="ios" />;
  }
  if (platform === "android") {
    return <BigBadge platform="android" />;
  }
  return (
    <div className="flex flex-col items-center gap-3 sm:flex-row">
      <BigBadge platform="ios" />
      <BigBadge platform="android" />
    </div>
  );
}

function BigBadge({ platform }: { platform: "ios" | "android" }) {
  // U7: replace with Branch link. For now, /coming-soon on either.
  const sub = platform === "ios" ? "App Store" : "Google Play";
  const lead = platform === "ios" ? "Download on the" : "Get it on";
  return (
    <Link
      href={`/coming-soon/${platform}`}
      className="inline-flex min-w-[220px] items-center gap-3 rounded-2xl border border-zinc-300 bg-zinc-900 px-6 py-4 text-left text-zinc-50 transition hover:bg-zinc-800 dark:border-zinc-700 dark:bg-zinc-50 dark:text-zinc-900 dark:hover:bg-zinc-200"
    >
      <span aria-hidden className="text-3xl leading-none">
        {platform === "ios" ? "" : "▶"}
      </span>
      <span className="flex flex-col">
        <span className="text-xs uppercase tracking-wider opacity-70">{lead}</span>
        <span className="text-base font-semibold leading-tight">{sub}</span>
      </span>
    </Link>
  );
}

function FallbackHint({ platform }: { platform: AppStorePlatform }) {
  if (platform === "unknown") return null;
  const otherLabel = platform === "ios" ? "Android" : "iPhone";
  return (
    <p className="text-xs text-zinc-500 dark:text-zinc-500">
      On {otherLabel}? <Link href="/join?force_other=1" className="underline-offset-2 hover:underline">Use the other store.</Link>
    </p>
  );
}
