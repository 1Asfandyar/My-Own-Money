require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"   # kept for ActiveAdmin's asset pipeline needs

Bundler.require(*Rails.groups)

module Hopin
  class Application < Rails::Application
    # Load Rails 8 defaults.
    # When upgrading incrementally, bump this one minor version at a time:
    #   7.0 → 7.1 → 7.2 → 8.0
    # Each bump may silently change framework behaviour — read the upgrade guide.
    config.load_defaults 8.0

    # Eager-load everything in lib/ except non-Ruby support directories.
    # This catches Zeitwerk constant-loading errors at boot rather than at runtime.
    config.autoload_lib(ignore: %w[assets tasks])

    # API-only strips most middleware (sessions, cookies, views).
    # We add the minimal subset back below so ActiveAdmin keeps working.
    config.api_only = true

    # Middleware required by ActiveAdmin (session-based authentication + flash).
    # Pure API controllers never touch these; the overhead is negligible.
    config.middleware.use Rack::MethodOverride
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
    config.middleware.use ActionDispatch::Flash
  end
end
