// E10-004 Public List — placeholder. Real implementation in U7.
// R11: visibility flip → 30s window via webhook revalidation + request-time
// SSR visibility check as defense-in-depth.

export const runtime = "edge";

type Props = {
  params: Promise<{ listId: string }>;
};

export default async function PublicListPage({ params }: Props) {
  const { listId } = await params;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-3 px-6 py-24 text-center">
      <p className="text-xs uppercase tracking-wider text-zinc-500">
        public list — U7 placeholder
      </p>
      <p className="font-mono text-sm">listId = {listId}</p>
    </main>
  );
}
