# LOB: Node.js Platform

## Stack
- Node.js 20 LTS with TypeScript 5.x
- pnpm for package management
- Vitest for unit/integration testing
- Playwright for E2E testing
- ESLint + Prettier for code quality

## Conventions
- Use `pnpm` exclusively (never npm or yarn)
- Strict TypeScript — no `any` types
- Prefer `const` assertions and satisfies operator
- Use `zod` for runtime validation
- All async functions must handle errors explicitly
- Barrel exports via index.ts in each module
