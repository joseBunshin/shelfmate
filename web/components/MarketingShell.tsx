// Page chrome shared across the marketing home and the four E10
// non-user landings. Header is a single wordmark — no nav, no menu —
// because these pages have one goal: convert.

import Link from "next/link";
import type { ReactNode } from "react";

type Props = {
  children: ReactNode;
  // when true, hide the header (used on rec/list/profile landings where
  // the hero IS the page and chrome is a distraction)
  bareHeader?: boolean;
};

export function MarketingShell({ children, bareHeader = false }: Props) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="mx-auto flex w-full max-w-6xl items-center px-6 py-5">
        <Link
          href="/"
          className="text-base font-semibold tracking-tight text-zinc-900 hover:opacity-80 dark:text-zinc-50"
        >
          ShelfMate
        </Link>
        {!bareHeader && (
          <span className="ml-auto text-sm text-zinc-500 dark:text-zinc-400">
            Books, with the people you actually know.
          </span>
        )}
      </header>

      {children}

      <footer className="mx-auto mt-auto w-full max-w-6xl px-6 py-10 text-center text-xs text-zinc-500 dark:text-zinc-500">
        <p>
          A{" "}
          <a href="https://bunshin.io" className="underline-offset-2 hover:underline">
            Bunshin Labs
          </a>{" "}
          project. v1 in development.
        </p>
      </footer>
    </div>
  );
}
