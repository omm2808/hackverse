import type { Metadata } from 'next';
import './globals.css';
import { APP_CONFIG } from '@fit-odyssey/config';

export const metadata: Metadata = {
  title: `${APP_CONFIG.NAME} — AI Fitness & Odisha Heritage`,
  description: APP_CONFIG.TAGLINE,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-odyssey-dark text-slate-100 antialiased min-h-screen">
        {children}
      </body>
    </html>
  );
}
