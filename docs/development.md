# Fit Odyssey — Development Guide

## Prerequisites
- Node.js >= 20
- pnpm >= 9
- PostgreSQL >= 15
- Expo Go / Android Studio / Xcode (for mobile development)

## Setup Commands
```bash
# Install all dependencies across monorepo
pnpm install

# Run type checks across all apps and packages
pnpm run type-check

# Run linter
pnpm run lint

# Build all apps and packages
pnpm run build
```

## Running Applications
```bash
# Start NestJS API (Port 3001)
pnpm --filter @fit-odyssey/api dev

# Start Next.js Web (Port 3000)
pnpm --filter @fit-odyssey/web dev

# Start Expo Mobile App
pnpm --filter @fit-odyssey/mobile dev
```
