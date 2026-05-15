# frozen_string_literal: true

module Transaction::Splits
  class Calculator
    SUPPORTED = %w[equal exact].freeze

    # Returns an array of hashes:
    #   { user_id:, owed_amount_cents:, split_method:, allocation_value: }
    #
    # equal: pass user_ids: [Integer, ...]
    # exact: pass user_shares: [{ user_id:, share_amount_cents: }, ...]
    #
    # Add a new entry to STRATEGIES and implement the corresponding private method
    # when adding support for percentage or shares splits.
    STRATEGIES = {
      "equal" => :calculate_equal,
      "exact" => :calculate_exact
    }.freeze

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

    def self.calculate_exact(amount_cents:, user_shares:, **)
      user_shares.map do |share|
        {
          user_id:           share[:user_id],
          owed_amount_cents: share[:share_amount_cents],
          split_method:      :exact,
          allocation_value:  share[:share_amount_cents]
        }
      end
    end
  end
end
