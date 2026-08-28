# syntax=docker/dockerfile:1

FROM node:20-alpine AS base
# package-lock.json was generated with npm 11; node:20-alpine ships npm 10,
# which resolves this lockfile's peer-dependency tree differently and makes
# `npm ci` report packages (webpack + friends, pulled in as a peer dep of
# @sentry/webpack-plugin) as missing. Pin npm to match.
RUN npm install -g npm@11.17.0

# ---- Dependencies -----------------------------------------------------
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- Build --------------------------------------------------------------
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Standalone output needs no runtime env vars at build time — every var in
# lib/env.ts is optional, so this image builds the same regardless of which
# services are configured at deploy time.
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
