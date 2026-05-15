module Api::V0::Contracts::Transactions
  class Update < Api::V0::ApplicationContract
    ALLOWED_TYPES    = Transaction.transaction_types.keys.freeze
    SUPPORTED_SPLITS = Transaction::Splits::Calculator::SUPPORTED.freeze

    params do
      required(:id).filled(:integer)
      optional(:title).filled(:string)
      optional(:transaction_type).filled(:string)
      optional(:amount_cents).filled(:integer)
      optional(:account_id).maybe(:integer)
      optional(:from_account_id).maybe(:integer)
      optional(:to_account_id).maybe(:integer)
      optional(:category_id).maybe(:integer)
      optional(:transaction_date).filled(:string)
      optional(:note).maybe(:string)
      optional(:currency_id).maybe(:integer)

      # shared expense fields
      optional(:paid_by).maybe(:integer)
      optional(:shared_by).maybe(:array)
      optional(:user_shares).maybe(:array)
      optional(:split_method).maybe(:string)
    end

    rule(:transaction_type) do
      next unless value
      key.failure("must be one of #{ALLOWED_TYPES.join(', ')}") unless ALLOWED_TYPES.include?(value)
    end

    rule(:amount_cents) do
      next unless value
      key.failure("must be greater than 0") if value <= 0
    end

    rule(:transaction_date) do
      next unless value
      Time.parse(value)
    rescue ArgumentError, TypeError
      key.failure("must be a valid ISO 8601 datetime")
    end

    rule(:from_account_id, :to_account_id) do
      next unless value && values[:to_account_id]
      key(:to_account_id).failure("must be different from from_account_id") if value == values[:to_account_id]
    end

    rule(:split_method) do
      next unless value
      key.failure("must be one of: #{SUPPORTED_SPLITS.join(', ')}") unless SUPPORTED_SPLITS.include?(value)
    end

    rule(:shared_by) do
      next if value.nil?
      key.failure("must have at least one user") if value.empty?
      key.failure("must be an array of integers") if value.any? { |v| !v.is_a?(Integer) }
    end

    rule(:user_shares) do
      next if value.nil?
      if value.empty?
        key.failure("must not be empty")
        next
      end
      if value.any? { |s| !s.is_a?(Hash) || !s[:user_id].is_a?(Integer) }
        key.failure("each entry must have an integer user_id")
        next
      end
      unless value.all? { |s| s.key?(:share) && s[:share].is_a?(Numeric) }
        key.failure("each entry must have a numeric share")
      end
    end

    rule(:split_method, :shared_by, :user_shares) do
      method = values[:split_method]
      next if method.nil?
      if method != "equal" && values[:shared_by]&.any?
        key(:shared_by).failure("must not be provided for #{method} split (use user_shares instead)")
      elsif method == "equal" && values[:user_shares]&.any?
        key(:user_shares).failure("must not be provided for equal split (use shared_by instead)")
      end
    end
  end
end
