"use client";

// R15 branded fallback for all 404-shape failures. Real implementation in U7.
// Single component switches copy by error.path (rec/u/list).

import { useEffect } from "react";

type Props = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function Error({ error, reset }: Props) {
  useEffect(() => {
    // U1.3 wires Sentry capture here.
    console.error(error);
  }, [error]);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 px-6 py-24 text-center">
      <h1 className="text-2xl font-semibold tracking-tight">
        Something went wrong
      </h1>
      <p className="max-w-md text-sm text-zinc-600">
        U7 will replace this with branded fallback copy specific to the route
        (rec / profile / list).
      </p>
      <button
        type="button"
        onClick={() => reset()}
        className="rounded-md border border-zinc-300 px-4 py-2 text-sm hover:bg-zinc-50"
      >
        Try again
      </button>
    </main>
  );
}
