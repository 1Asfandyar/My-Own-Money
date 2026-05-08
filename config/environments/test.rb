require "active_support/core_ext/integer/time"

Rails.application.configure do
  # ── Loading ─────────────────────────────────────────────────────────────────
  config.enable_reloading = false

  # Eager-load in CI to catch Zeitwerk / autoloading errors before deployment.
  config.eager_load = ENV["CI"].present?

  # ── Static file serving ─────────────────────────────────────────────────────
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # ── Errors & caching ────────────────────────────────────────────────────────
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store                       = :null_store

  # :rescuable renders error templates for known exception classes;
  # everything else still raises (so test failures surface cleanly).
  config.action_dispatch.show_exceptions = :rescuable

  # ── Security ────────────────────────────────────────────────────────────────
  config.action_controller.allow_forgery_protection = false

  # ── Mailer ──────────────────────────────────────────────────────────────────
  config.action_mailer.perform_caching  = false
  config.action_mailer.delivery_method = :test

  # ── Deprecations ────────────────────────────────────────────────────────────
  # Fail loudly in tests so deprecation warnings are caught before production.
  config.active_support.deprecation                    = :stderr
  config.active_support.disallowed_deprecation         = :raise
  config.active_support.disallowed_deprecation_warnings = []
end
