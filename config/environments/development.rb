require "active_support/core_ext/integer/time"

Rails.application.configure do
  # ── Reloading & loading ─────────────────────────────────────────────────────
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  # ── Caching ─────────────────────────────────────────────────────────────────
  # Toggle with: bin/rails dev:cache
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # ── Mailer ──────────────────────────────────────────────────────────────────
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  # ── ActiveRecord ────────────────────────────────────────────────────────────
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  # ── ActiveJob ───────────────────────────────────────────────────────────────
  config.active_job.queue_adapter = :solid_queue
  config.active_job.verbose_enqueue_logs = true

  # ── Deprecations ────────────────────────────────────────────────────────────
  # Rails 8 uses ActiveSupport::Deprecation.new internally.
  # The old config.active_support.deprecation = :log API is removed in Rails 8.
  # Deprecation warnings now always go to the log in development.
end
