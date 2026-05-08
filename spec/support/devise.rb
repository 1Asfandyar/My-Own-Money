# Devise test helpers for request specs.
# For request specs we authenticate via JWT headers, not Devise sign_in helpers.
# This file is here for completeness if controller specs are ever added.
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end
