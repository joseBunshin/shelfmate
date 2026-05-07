// E10-005 Join ShelfMate CTA + App Store / Play Store redirect — placeholder.
// Real implementation in U7 attaches Branch deferred install token to the
// store URL so referrer context survives install (R13/R14).

import { headers } from "next/headers";
import { detectPlatform } from "@/lib/branch";

export const runtime = "edge";

export default async function JoinPage() {
  const ua = (await headers()).get("user-agent");
  const platform = detectPlatform(ua);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-3 px-6 py-24 text-center">
      <p className="text-xs uppercase tracking-wider text-zinc-500">
        join — U7 placeholder
      </p>
      <p className="font-mono text-sm">detected platform = {platform}</p>
      <p className="max-w-xs text-sm text-zinc-600">
        U7 will redirect to the App Store on iOS, Play Store on Android, and
        offer both badges on unknown platforms.
      </p>
    </main>
  );
}
