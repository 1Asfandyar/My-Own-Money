# frozen_string_literal: true

module Transaction::Splits
  class Calculator
    SUPPORTED = %w[equal exact percentage shares].freeze

    # Dispatch table — add a new entry here when introducing a new split method.
    STRATEGIES = {
      "equal"      => :calculate_equal,
      "exact"      => :calculate_exact,
      "percentage" => :calculate_percentage,
      "shares"     => :calculate_shares
    }.freeze

    # Returns an array of hashes:
    #   { user_id:, owed_amount_cents:, split_method:, allocation_value: }
    #
    # equal:      pass user_ids: [Integer, ...]
    # exact:      pass user_shares: [{ user_id:, share: }]  — share = amount in cents
    # percentage: pass user_shares: [{ user_id:, share: }]  — share = percentage (must sum to 100)
    # shares:     pass user_shares: [{ user_id:, share: }]  — share = relative share count
    def self.calculate(method:, amount_cents:, **options)
      strategy = STRATEGIES[method.to_s]
      raise ArgumentError, "Unsupported split method: #{method}" unless strategy

      send(strategy, amount_cents: amount_cents, **options)
    end

    private

    def self.calculate_equal(amount_cents:, user_ids:, **)
      count     = user_ids.size
      base      = amount_cents / count
      remainder = amount_cents % count

      user_ids.each_with_index.map do |user_id, index|
        {
          user_id:           user_id,
          owed_amount_cents: base + (index.zero? ? remainder : 0),
          split_method:      :equal,
          allocation_value:  nil
        }
      end
    end

    # share = exact amount in cents for each user
    def self.calculate_exact(amount_cents:, user_shares:, **)
      user_shares.map do |s|
        {
          user_id:           s[:user_id],
          owed_amount_cents: s[:share],
          split_method:      :exact,
          allocation_value:  s[:share]
        }
      end
    end

    # share = percentage value per user (must sum to 100)
    # Remainder from floor-division is added to the first user.
    def self.calculate_percentage(amount_cents:, user_shares:, **)
      amounts    = user_shares.map { |s| (amount_cents * s[:share] / 100.0).floor }
      amounts[0] += amount_cents - amounts.sum

      user_shares.each_with_index.map do |s, i|
        {
          user_id:           s[:user_id],
          owed_amount_cents: amounts[i],
          split_method:      :percentage,
          allocation_value:  s[:share]
        }
      end
    end

    # share = relative share count per user (no fixed total required)
    # Remainder from floor-division is added to the first user.
    def self.calculate_shares(amount_cents:, user_shares:, **)
      total_shares = user_shares.sum { |s| s[:share] }.to_f
      amounts      = user_shares.map { |s| (amount_cents * s[:share] / total_shares).floor }
      amounts[0]  += amount_cents - amounts.sum

      user_shares.each_with_index.map do |s, i|
        {
          user_id:           s[:user_id],
          owed_amount_cents: amounts[i],
          split_method:      :shares,
          allocation_value:  s[:share]
        }
      end
    end
  end
end
