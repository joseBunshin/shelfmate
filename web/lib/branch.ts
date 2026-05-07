// Branch URL helpers for the web project. Server-side only — no SDK.
//
// Per plan U1 and U7: the `branch-sdk` npm package depends on window/document
// and breaks in Vercel Edge runtime. We assemble Branch URLs from Branch's
// documented URL template, no SDK needed.
//
// U1.3 wires BRANCH_LINK_DOMAIN from env; placeholder default until then.

const BRANCH_LINK_DOMAIN =
  process.env.NEXT_PUBLIC_BRANCH_LINK_DOMAIN ?? "link.shelfmate.app";

export type AppStorePlatform = "ios" | "android" | "unknown";

/**
 * Build the App Store / Play Store redirect URL with deferred deep link token
 * attached so Branch can resolve referrer context post-install (R13/R14).
 */
export function buildJoinUrl(
  platform: AppStorePlatform,
  fromUserId?: string
): string {
  const params = new URLSearchParams();
  if (fromUserId) params.set("from_user_id", fromUserId);
  params.set("platform", platform);

  return `https://${BRANCH_LINK_DOMAIN}/join?${params.toString()}`;
}

/**
 * Detect platform from request user-agent string. Falls back to 'unknown'
 * when the UA is missing or doesn't match either iOS or Android patterns.
 */
export function detectPlatform(userAgent: string | null): AppStorePlatform {
  if (!userAgent) return "unknown";
  if (/iPhone|iPad|iPod|iOS/i.test(userAgent)) return "ios";
  if (/Android/i.test(userAgent)) return "android";
  return "unknown";
}
