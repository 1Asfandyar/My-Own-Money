require_relative 'seed/user_seed'
Rails.logger.info "Seeding currencies..."
require_relative 'seed/currency_seed'
Rails.logger.info "Seeded currencies. Total count: #{Currency.count}"
Rails.logger.info "Seeding categories..."
require_relative 'seed/category_seed'
require_relative 'seed/account_seed'
