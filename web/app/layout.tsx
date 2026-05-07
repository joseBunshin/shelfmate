import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "ShelfMate — books with the people you actually know",
    template: "%s · ShelfMate",
  },
  description:
    "Track what you're reading, share notes with close friends, get recs from people whose taste you trust. iOS + Android.",
  metadataBase: new URL("https://shelfmate.app"),
  openGraph: {
    title: "ShelfMate",
    description:
      "Personal book tracking + a closed friend graph. iOS + Android.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
