# syntax = docker/dockerfile:1

# ── IMPORTANT ──────────────────────────────────────────────────────────────────
# RUBY_VERSION must match .ruby-version and the `ruby` directive in Gemfile.
# The previous Dockerfile had ARG RUBY_VERSION=3.2.11 which mismatched
# .ruby-version (3.4.5) — production was running a completely different Ruby.
# ───────────────────────────────────────────────────────────────────────────────
ARG RUBY_VERSION=3.4.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# RUBY_YJIT_ENABLE=1 enables YJIT JIT compiler on Ruby 3.3+.
# Rails 8 enables YJIT automatically, but the env var is the explicit opt-in.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RUBY_YJIT_ENABLE="1"

# ── Build stage ────────────────────────────────────────────────────────────────
# A throwaway stage that installs compilers and dev headers.
# These never land in the final image, keeping it lean.
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install gems first (before copying app code) so Docker layer cache is
# preserved across code-only changes — only re-runs when Gemfile changes.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ \
           "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy the full application code.
COPY . .

# Precompile bootsnap code so the app boots faster at runtime.
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets (ActiveAdmin CSS/JS via Sprockets).
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ── Final / runtime stage ──────────────────────────────────────────────────────
FROM base

# Install only runtime libraries — no compilers, no dev headers.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libvips \
      postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy compiled gems and application from the build stage.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as non-root for security.
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

USER rails:rails

# Entrypoint runs db:prepare (creates DB + runs pending migrations) on first boot.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000

# Start Puma; can be overridden by Kamal or docker-compose for job workers.
CMD ["./bin/rails", "server"]
