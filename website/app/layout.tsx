import type { Metadata } from "next";
import "./globals.css";

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://letterloom.app";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "LetterLoom - Premium Word Game",
    template: "%s | LetterLoom",
  },
  description:
    "LetterLoom is a premium word game featuring solo offline play against AI and live online multiplayer. Thread letters together on a 15x15 board, craft high-scoring words, and master the Loom.",
  keywords: [
    "LetterLoom",
    "word game",
    "Scrabble alternative",
    "multiplayer word game",
    "offline word game",
    "ENABLE1 dictionary",
    "word puzzle",
    "board game",
    "iOS word game",
    "Android word game",
  ],
  authors: [{ name: "Sulaymaan Abubakr" }],
  creator: "Sulaymaan Abubakr",
  publisher: "LetterLoom",
  icons: {
    icon: [
      { url: "/logo.png" },
      { url: "/icon.png", type: "image/png" },
    ],
    apple: [{ url: "/apple-icon.png" }],
    shortcut: ["/logo.png"],
  },
  openGraph: {
    title: "LetterLoom - Premium Word Game",
    description:
      "Solo offline play against AI + live online multiplayer. Available on iOS & Android.",
    url: siteUrl,
    siteName: "LetterLoom",
    images: [
      {
        url: "/logo.png",
        width: 1024,
        height: 1024,
        alt: "LetterLoom Official Logo",
      },
    ],
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "LetterLoom - Premium Word Game",
    description:
      "Solo offline play against AI + live online multiplayer. Crafted for word masters.",
    images: ["/logo.png"],
    creator: "@letterloom",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" data-scroll-behavior="smooth">
      <body>{children}</body>
    </html>
  );
}
