# Lint all factories at suite start to catch misconfigured traits and associations.
# This runs once and fails fast if a factory is broken, rather than mid-suite.
RSpec.configure do |config|
  config.before(:suite) do
    FactoryBot.lint(traits: true)
  end
end
