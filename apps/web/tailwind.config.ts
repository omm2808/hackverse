import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        odyssey: {
          dark: '#0a0d14',
          card: '#121824',
          border: '#1f293d',
          gold: '#f59e0b',
          crimson: '#ef4444',
          emerald: '#10b981',
        },
      },
    },
  },
  plugins: [],
};

export default config;
