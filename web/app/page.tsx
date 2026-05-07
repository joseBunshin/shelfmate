// Root marketing page. The web project's primary job is the five non-user
// landing routes from buildspec E10 (rec / list / profile / join). The root
// path is a small marketing surface so the apex domain isn't bare while we
// drive traffic via deep links.

import Link from "next/link";

export const runtime = "edge";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col">
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-6">
        <span className="text-base font-semibold tracking-tight text-zinc-900 dark:text-zinc-50">
          ShelfMate
        </span>
        <nav className="text-sm text-zinc-600 dark:text-zinc-400">
          <a href="#features" className="hover:text-zinc-900 dark:hover:text-zinc-50">
            What it does
          </a>
        </nav>
      </header>

      <section className="mx-auto flex w-full max-w-3xl flex-1 flex-col items-center justify-center gap-6 px-6 py-16 text-center">
        <h1 className="text-balance text-4xl font-semibold tracking-tight text-zinc-900 sm:text-5xl dark:text-zinc-50">
          Books, with the people you actually know.
        </h1>
        <p className="max-w-xl text-balance text-base text-zinc-600 sm:text-lg dark:text-zinc-400">
          Track what you&rsquo;re reading. Share notes with close friends. Get
          recs from people whose taste you trust — not strangers, not
          algorithms.
        </p>

        <div className="mt-2 flex flex-col items-center gap-3 sm:flex-row">
          <StoreBadge platform="ios" />
          <StoreBadge platform="android" />
        </div>

        <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-500">
          Coming soon. iOS + Android only — no web app.
        </p>
      </section>

      <section
        id="features"
        className="mx-auto grid w-full max-w-5xl gap-6 px-6 py-16 sm:grid-cols-3"
      >
        <Feature
          eyebrow="Closed graph"
          title="Only friends you accept."
          body="No public feed, no follower count, no strangers. Notes you write are seen by friends — and only the ones you both still have set to share."
        />
        <Feature
          eyebrow="Honest tracking"
          title="Reading, not performing."
          body="Mark a book Reading, Finished, or Dropped. Add a private note or one to share. No streaks, no leaderboards, no reading challenges."
        />
        <Feature
          eyebrow="Recs that land"
          title="One book, one friend."
          body="Send a recommendation with a sentence about why. They get a notification — not a feed item. AI helps you find the right next book based on what your friends are loving."
        />
      </section>

      <footer className="mx-auto w-full max-w-6xl px-6 py-10 text-center text-xs text-zinc-500 dark:text-zinc-500">
        <p>
          A{" "}
          <a
            href="https://bunshin.io"
            className="underline-offset-2 hover:underline"
          >
            Bunshin Labs
          </a>{" "}
          project. v1 in development.
        </p>
      </footer>
    </main>
  );
}

function Feature({
  eyebrow,
  title,
  body,
}: {
  eyebrow: string;
  title: string;
  body: string;
}) {
  return (
    <div className="flex flex-col gap-2">
      <p className="text-xs font-medium uppercase tracking-wider text-zinc-500 dark:text-zinc-400">
        {eyebrow}
      </p>
      <h3 className="text-base font-semibold text-zinc-900 dark:text-zinc-50">
        {title}
      </h3>
      <p className="text-sm leading-relaxed text-zinc-600 dark:text-zinc-400">
        {body}
      </p>
    </div>
  );
}

function StoreBadge({ platform }: { platform: "ios" | "android" }) {
  // U7 wires real App Store / Play Store URLs with Branch deferred-install
  // tokens (R13/R14). Until then, /join handles platform detection so these
  // can route through it.
  const label =
    platform === "ios" ? "Download on the App Store" : "Get it on Google Play";
  const sub = platform === "ios" ? "App Store" : "Google Play";

  return (
    <Link
      href="/join"
      className="inline-flex min-w-[180px] items-center gap-3 rounded-xl border border-zinc-300 bg-zinc-900 px-4 py-3 text-left text-zinc-50 transition hover:bg-zinc-800 dark:border-zinc-700 dark:bg-zinc-50 dark:text-zinc-900 dark:hover:bg-zinc-200"
    >
      <span aria-hidden className="text-2xl leading-none">
        {platform === "ios" ? "" : "▶"}
      </span>
      <span className="flex flex-col">
        <span className="text-[10px] uppercase tracking-wider opacity-70">
          {label.split(" on ")[0]}
        </span>
        <span className="text-sm font-semibold leading-tight">{sub}</span>
      </span>
    </Link>
  );
}
