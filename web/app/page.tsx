// Root route. The web project's job is to serve the five non-user landing
// pages from buildspec E10 (rec landing, social discovery, inviter profile,
// public list, App Store redirect). The root path itself is intentionally
// minimal — there is no general "marketing site" in v1.

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-zinc-50 px-6 py-24 text-center dark:bg-black">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-50">
        ShelfMate
      </h1>
      <p className="max-w-md text-sm text-zinc-600 dark:text-zinc-400">
        Personal book tracking for the people you actually know. Available on
        iOS and Android.
      </p>
      <p className="text-xs text-zinc-500 dark:text-zinc-500">
        v1 in development — landing pages live at{" "}
        <code className="font-mono">/rec/[id]</code>,{" "}
        <code className="font-mono">/u/[id]</code>,{" "}
        <code className="font-mono">/list/[id]</code>, and{" "}
        <code className="font-mono">/join</code>.
      </p>
    </main>
  );
}
