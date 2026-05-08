require "spec_helper"

# ── Code coverage (must be required before application loads) ──────────────
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
end

# ── Rails environment ──────────────────────────────────────────────────────
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "shoulda/matchers"

# ── Support files ──────────────────────────────────────────────────────────
# Auto-require all files in spec/support/ (matchers, shared examples, helpers).
Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

# ── Database ───────────────────────────────────────────────────────────────
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# ── RSpec configuration ────────────────────────────────────────────────────
RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true

  # Infer spec type from file location (e.g. spec/models → type: :model).
  config.infer_spec_type_from_file_location!

  # Filter noisy Rails gem paths from backtraces.
  config.filter_rails_from_backtrace!

  # Include FactoryBot helpers (build, create, attributes_for, etc.).
  config.include FactoryBot::Syntax::Methods
end

# ── Shoulda::Matchers ─────────────────────────────────────────────────────
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
