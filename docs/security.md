# Fit Odyssey — Security Architecture

## Security Principles
1. **Zero Raw Video Transmission**: On-device pose detection guarantees camera frames never touch any network interface.
2. **Server-Side Authorization**: NestJS Guards (`AuthGuard`, `RolesGuard`) enforce resource ownership and role permissions. Clients are untrusted.
3. **No Client-Calculated XP**: All XP calculations, streak increments, and badge awarding occur exclusively in NestJS services.
4. **Input Validation**: Strict schema validation using Zod and class-validator on all incoming payloads.
5. **Rate Limiting & Headers**: Helmet, CORS origin restriction, and throttled endpoints.
