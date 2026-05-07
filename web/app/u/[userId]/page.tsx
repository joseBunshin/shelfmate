// E10-002 Social Discovery + E10-003 Inviter Profile — placeholder.
// Real implementation in U7. The same route serves both — content varies by
// referrer hint (lighter for social discovery, fuller for inviter profile).

export const runtime = "edge";

type Props = {
  params: Promise<{ userId: string }>;
};

export default async function ProfilePage({ params }: Props) {
  const { userId } = await params;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-3 px-6 py-24 text-center">
      <p className="text-xs uppercase tracking-wider text-zinc-500">
        inviter profile — U7 placeholder
      </p>
      <p className="font-mono text-sm">userId = {userId}</p>
    </main>
  );
}
