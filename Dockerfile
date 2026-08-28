# syntax=docker/dockerfile:1

FROM node:20-alpine AS base

# ---- Dependencies -----------------------------------------------------
FROM base AS deps
WORKDIR /app
# .npmrc carries legacy-peer-deps=true, required for npm ci to resolve
# @sentry/webpack-plugin's webpack peer dependency the same way it does
# outside Docker.
COPY package.json package-lock.json .npmrc ./
RUN npm ci

# ---- Build --------------------------------------------------------------
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Most of lib/env.ts is read at runtime (server-only, or via next.config.mjs's
# `env` field) and doesn't need to exist at build time. NEXT_PUBLIC_* vars are
# the exception — Next.js inlines them into the client bundle during `next
# build`, so they must be passed as build args (see docker-compose.yml's
# `build.args`), not just as container-runtime env vars, or client-side code
# (e.g. the Supabase browser client) silently sees them as empty.
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ---- Runtime --------------------------------------------------------------
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
