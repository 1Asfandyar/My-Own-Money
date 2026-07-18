module Api::V0::Contracts::Transactions
  class Create < Api::V0::ApplicationContract
    ALLOWED_TYPES    = Transaction.transaction_types.keys.freeze
    SUPPORTED_SPLITS = Transaction.split_methods.keys.freeze

    params do
      required(:title).filled(:string)
      required(:transaction_type).filled(:string)
      required(:amount_cents).filled(:integer)
      optional(:account_id).maybe(:integer)
      optional(:category_id).maybe(:integer)
      optional(:from_account_id).maybe(:integer)
      optional(:to_account_id).maybe(:integer)
      optional(:transaction_date).maybe(:string)
      optional(:note).maybe(:string)

      # shared expense fields
      optional(:shared_by).maybe(:array)   # equal split: array of user IDs
      optional(:user_shares).maybe(:array) # non-equal splits: array of { user_id:, share: }
      optional(:split_method).maybe(:string)

      # settlement fields
      optional(:paid_by_id).maybe(:integer)
      optional(:paid_to_id).maybe(:integer)
      optional(:paid_by_account_id).maybe(:integer)
      optional(:paid_to_account_id).maybe(:integer)

      # group transaction fields
      optional(:group_id).maybe(:integer)
    end

    rule(:transaction_type) do
      key.failure("must be one of #{ALLOWED_TYPES.join(', ')}") unless ALLOWED_TYPES.include?(value)
    end

    rule(:amount_cents) do
      key.failure("must be greater than 0") if value <= 0
    end

    rule(:transaction_date) do
      next if value.nil?

      Time.parse(value)
    rescue ArgumentError, TypeError
      key.failure("must be a valid ISO 8601 datetime")
    end

    # --- personal / shared expense ---

    rule(:account_id) do
      next if values[:transaction_type] == "transfer"
      next if values[:transaction_type] == "settlement"
      key.failure("is required") if value.nil?
    end

    rule(:category_id) do
      next if values[:transaction_type] == "transfer"
      next if values[:transaction_type] == "settlement"
      key.failure("is required") if value.nil?
    end

    # --- settlement ---

    rule(:paid_to_id) do
      next unless values[:transaction_type] == "settlement"
      key.failure("is required for settlement") if value.nil?
    end

    rule(:paid_by_id) do
      next unless values[:transaction_type] == "settlement"
      key.failure("is required for settlement") if value.nil?
    end

    rule(:paid_by_id, :paid_to_id) do
      next unless values[:transaction_type] == "settlement"
      next if values[:paid_by_id].nil? || values[:paid_to_id].nil?
      key(:paid_by_id).failure("must be different from paid_to_id") if values[:paid_by_id] == values[:paid_to_id]
    end

    # --- transfer ---

    rule(:from_account_id) do
      next unless values[:transaction_type] == "transfer"
      key.failure("is required for transfer") if value.nil?
    end

    rule(:to_account_id) do
      next unless values[:transaction_type] == "transfer"
      key.failure("is required for transfer") if value.nil?
    end

    rule(:from_account_id, :to_account_id) do
      next unless value && values[:to_account_id]
      key(:to_account_id).failure("must be different from from_account_id") if value == values[:to_account_id]
    end

    # --- shared expense: equal split (shared_by) ---

    rule(:shared_by) do
      next unless values[:transaction_type] == "expense" && !value.nil?
      key.failure("must have at least one user") if value.empty?
      key.failure("must be an array of integers") if value.any? { |v| !v.is_a?(Integer) }
    end

    # --- shared expense: non-equal splits (user_shares) ---

    rule(:user_shares) do
      next if value.nil?
      next unless values[:transaction_type] == "expense"

      if value.empty?
        key.failure("must not be empty")
        next
      end

      if value.any? { |s| !s.is_a?(Hash) || !s[:user_id].is_a?(Integer) }
        key.failure("each entry must have an integer user_id")
        next
      end

      method = values[:split_method]

      case method
      when "exact"
        unless value.all? { |s| s[:share].is_a?(Integer) && s[:share] >= 0 }
          key.failure("each entry must have a non-negative integer share for exact split")
          next
        end
        total = value.sum { |s| s[:share] }
        key.failure("shares must sum to #{values[:amount_cents]} for exact split") unless total == values[:amount_cents]
      when "percentage"
        unless value.all? { |s| s[:share].is_a?(Numeric) && s[:share] > 0 }
          key.failure("each entry must have a positive numeric share for percentage split")
          next
        end
        total = value.sum { |s| s[:share] }
        key.failure("percentage shares must sum to 100") unless total == 100
      when "shares"
        unless value.all? { |s| s[:share].is_a?(Numeric) && s[:share] > 0 }
          key.failure("each entry must have a positive numeric share count for shares split")
        end
      end
    end

    # Ensure shared_by and user_shares are not mixed for incompatible split methods.
    rule(:split_method, :shared_by, :user_shares) do
      method = values[:split_method]
      next if method.nil?

      if method != "equal" && values[:shared_by]&.any?
        key(:shared_by).failure("must not be provided for #{method} split (use user_shares instead)")
      elsif method == "equal" && values[:user_shares]&.any?
        key(:user_shares).failure("must not be provided for equal split (use shared_by instead)")
      end
    end

    # --- group transaction ---

    rule(:group_id) do
      next if value.nil?
      is_shared = values[:transaction_type] == "expense" &&
                  (values[:shared_by]&.any? || values[:user_shares]&.any?)
      key.failure("is only allowed for shared expenses") unless is_shared
    end

    # --- split_method: required for any shared expense ---

    rule(:split_method) do
      is_shared = values[:transaction_type] == "expense" &&
                  (values[:shared_by]&.any? || values[:user_shares]&.any?)
      next unless is_shared
      key.failure("is required for shared expense") if value.nil?
      next if value.nil?
      key.failure("must be one of: #{SUPPORTED_SPLITS.join(', ')}") unless SUPPORTED_SPLITS.include?(value)
    end
  end
end
