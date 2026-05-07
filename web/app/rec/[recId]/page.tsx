// E10-001 Direct Rec Landing — placeholder. Real implementation in U7.
// 2s LTE budget: above-fold cover + sender name + first line of note must
// render within 2 seconds (R10, AE5).

export const runtime = "edge";

type Props = {
  params: Promise<{ recId: string }>;
};

export default async function RecLandingPage({ params }: Props) {
  const { recId } = await params;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-3 px-6 py-24 text-center">
      <p className="text-xs uppercase tracking-wider text-zinc-500">
        rec landing — U7 placeholder
      </p>
      <p className="font-mono text-sm">recId = {recId}</p>
    </main>
  );
}
