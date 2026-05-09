source "https://rubygems.org"

ruby "3.4.5"

# ─── Core ─────────────────────────────────────────────────────────────────────
gem "rails", "~> 8.0"
gem "pg", "~> 1.1"
gem "puma", ">= 6.0"
gem "bootsnap", require: false

# ─── Assets (required by ActiveAdmin — keep Sprockets) ────────────────────────
gem "sprockets-rails"
gem "dartsass-sprockets"      # Dart Sass processor for Sprockets (replaces sassc-rails)

# ─── API & Middleware ──────────────────────────────────────────────────────────
gem "rack-cors"
gem "rack-attack"             # rate limiting + brute-force protection

# ─── Authentication ───────────────────────────────────────────────────────────
gem "devise"
gem "devise-jwt"

# ─── Admin Panel ──────────────────────────────────────────────────────────────
gem "activeadmin"             # bump to ~> 4.0 once released for full Rails 8 support

# ─── Authorization ────────────────────────────────────────────────────────────
gem "pundit"

# ─── Service / Operation Pattern ──────────────────────────────────────────────
gem "dry-matcher"
gem "dry-monads"
gem "dry-types"
gem "dry-validation"

# ─── Serialization (blueprinter only; active_model_serializers removed) ───────
gem "blueprinter"

# ─── API Documentation ────────────────────────────────────────────────────────
gem "apipie-rails"

# ─── Pagination ───────────────────────────────────────────────────────────────
gem "kaminari"                # kept — ActiveAdmin depends on it internally
gem "pagy"                    # fast pagination for API layer

# ─── Development + Test ───────────────────────────────────────────────────────
group :development, :test do
  gem "debug", platforms: %i[mri windows jruby]  # replaces byebug (broken on Ruby 3.4)
  gem "dotenv-rails"
  gem "rspec-rails"
  gem "rspec_junit_formatter"
  gem "factory_bot_rails"
  gem "faker"
  gem "brakeman", require: false          # static security analysis
  gem "bundler-audit", require: false     # vulnerable gem CVE checker
end

group :development do
  gem "web-console"
  gem "rubocop-rails-omakase", require: false  # Omakase Rails style guide
  gem "annotaterb"                             # schema annotations on models
end

group :test do
  gem "simplecov", require: false         # code coverage
  gem "shoulda-matchers"                  # model & controller one-liner matchers
  gem "json_matchers"                     # match_json_schema matcher for request specs
end
