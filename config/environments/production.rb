require "active_support/core_ext/integer/time"

Rails.application.configure do
  # ── Loading ─────────────────────────────────────────────────────────────────
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.require_master_key = false

  # ── SSL ─────────────────────────────────────────────────────────────────────
  # Kamal deploys through Thruster / kamal-proxy which terminates TLS.
  # assume_ssl tells Rails the connection is already secure (sets secure cookies,
  # HSTS headers) without Rails itself handling TLS.
  config.assume_ssl = true
  config.force_ssl = true

  # ── Logging ─────────────────────────────────────────────────────────────────
  # Log to STDOUT so container runtimes (Docker, Kubernetes) capture output.
  config.logger = ActiveSupport::Logger.new($stdout)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  config.log_tags  = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # ── Cache ───────────────────────────────────────────────────────────────────
  # Default: in-process memory cache. For multi-process deployments switch to
  # Redis or Solid Cache (Rails 8 default for new apps):
  #
  #   gem "solid_cache"   # config/cache.yml → db-backed, no Redis needed
  #   config.cache_store = :solid_cache_store
  #
  #   — OR —
  #
  #   config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
  #
  config.cache_store = :memory_store, { size: 64.megabytes }

  # ── Active Job ──────────────────────────────────────────────────────────────
  # Default :async runs jobs in-process (lost on restart).
  # For production use Solid Queue (no Redis) or Sidekiq:
  #
  #   gem "solid_queue"
  #   config.active_job.queue_adapter = :solid_queue
  #
  #   — OR —
  #
  #   gem "sidekiq"
  #   config.active_job.queue_adapter = :sidekiq
  #
  # config.active_job.queue_name_prefix = "hopin_production"

  # ── Mailer ──────────────────────────────────────────────────────────────────
  config.action_mailer.perform_caching = false
  # config.action_mailer.default_url_options = { host: "yourdomain.com" }
  # config.action_mailer.delivery_method  = :smtp
  # config.action_mailer.smtp_settings    = { address: ENV["SMTP_HOST"], ... }

  # ── I18n ────────────────────────────────────────────────────────────────────
  config.i18n.fallbacks = true

  # ── Deprecations ────────────────────────────────────────────────────────────
  config.active_support.report_deprecations = false

  # ── ActiveRecord ────────────────────────────────────────────────────────────
  config.active_record.dump_schema_after_migration = false

  # ── DNS rebinding protection ─────────────────────────────────────────────────
  # Restrict which Host header values the app accepts.
  # Uncomment and set your production domain(s).
  #
  # config.hosts = [
  #   "yourdomain.com",
  #   /.*\.yourdomain\.com/
  # ]
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
