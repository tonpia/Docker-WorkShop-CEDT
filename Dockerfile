# syntax=docker/dockerfile:1.7

# =============================================================================
# Builder stage — installs production dependencies only, on a fresh Node base.
# =============================================================================

# step-4a
FROM node:20.11-slim AS builder
#   Do NOT use `node:latest` — we want reproducible builds across the cohort.

WORKDIR /app

# step-4b
COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev
# Trivy flags proxy-addr 2.0.7 (CRITICAL, fixed in 2.0.8). app/ must stay untouched, so bump it in the image only.
RUN npm update proxy-addr --omit=dev

# step-4c
COPY app/ ./

# =============================================================================
# Runtime stage — slim final image. Nothing from builder's caches leaks in.
# =============================================================================

# step-4d
FROM node:20.11-slim

WORKDIR /app

# step-4e
COPY --from=builder /app /app

# Trivy flags CRITICAL findings in the old Debian 12.5 base and in the npm bundled in the image (tar).
# Patch the OS packages and drop npm, which the runtime does not need.
RUN apt-get update \
 && apt-get upgrade -y \
 && rm -rf /var/lib/apt/lists/* /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

ENV NODE_ENV=production
EXPOSE 3000

# step-4f
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

# step-4g
CMD ["node", "src/index.js"]
