// Two-up store badge CTAs that route through /join for platform-aware
// redirect. Fallback layout when platform is unknown.
//
// Real Branch deferred-deep-link tokens get attached in U7 proper; right
// now these route to /join which does the platform-detection placeholder.

import Link from "next/link";

type Props = {
  // optional caller hint — when caller already detected platform, render
  // the correct single CTA inline rather than two-up.
  detectedPlatform?: "ios" | "android" | "unknown";
  className?: string;
  fromUserId?: string;
  fromRecId?: string;
};

export function StoreBadges({
  detectedPlatform = "unknown",
  className = "",
  fromUserId,
  fromRecId,
}: Props) {
  const params = new URLSearchParams();
  if (fromUserId) params.set("from_user_id", fromUserId);
  if (fromRecId) params.set("from_rec_id", fromRecId);
  const query = params.toString();
  const joinHref = query ? `/join?${query}` : "/join";

  if (detectedPlatform === "ios") {
    return (
      <div className={className}>
        <Badge platform="ios" href={joinHref} />
      </div>
    );
  }
  if (detectedPlatform === "android") {
    return (
      <div className={className}>
        <Badge platform="android" href={joinHref} />
      </div>
    );
  }

  return (
    <div className={`flex flex-col items-center gap-3 sm:flex-row sm:justify-center ${className}`}>
      <Badge platform="ios" href={joinHref} />
      <Badge platform="android" href={joinHref} />
    </div>
  );
}

function Badge({ platform, href }: { platform: "ios" | "android"; href: string }) {
  const sub = platform === "ios" ? "App Store" : "Google Play";
  const lead = platform === "ios" ? "Download on the" : "Get it on";

  return (
    <Link
      href={href}
      className="inline-flex min-w-[180px] items-center gap-3 rounded-xl border border-zinc-300 bg-zinc-900 px-4 py-3 text-left text-zinc-50 transition hover:bg-zinc-800 dark:border-zinc-700 dark:bg-zinc-50 dark:text-zinc-900 dark:hover:bg-zinc-200"
    >
      <span aria-hidden className="text-2xl leading-none">
        {platform === "ios" ? "" : "▶"}
      </span>
      <span className="flex flex-col">
        <span className="text-[10px] uppercase tracking-wider opacity-70">{lead}</span>
        <span className="text-sm font-semibold leading-tight">{sub}</span>
      </span>
    </Link>
  );
}
