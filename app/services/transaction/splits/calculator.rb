# frozen_string_literal: true

module Transaction::Splits
  class Calculator
    SUPPORTED = %w[equal].freeze

    # Returns an array of hashes:
    #   { user_id:, owed_amount_cents:, split_method:, allocation_value: }
    # Add a new entry to STRATEGIES and implement the corresponding private method
    # when adding support for percentage, shares, or exact splits.
    STRATEGIES = {
      "equal" => :calculate_equal
    }.freeze

    def self.calculate(method:, amount_cents:, user_ids:, **options)
      strategy = STRATEGIES[method.to_s]
      raise ArgumentError, "Unsupported split method: #{method}" unless strategy

      send(strategy, amount_cents: amount_cents, user_ids: user_ids, **options)
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
  end
end
