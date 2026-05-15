module Api::V0::Transactions
  class Create
    include Api::V0::ApplicationOperation

    ALLOWED_TYPES    = Transaction.transaction_types.keys.freeze
    SUPPORTED_SPLITS = Transaction::Splits::Calculator::SUPPORTED.freeze

    class Contract < Api::V0::ApplicationContract
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
        optional(:currency_id).maybe(:integer)

        # shared expense fields
        optional(:paid_by).maybe(:integer)
        optional(:shared_by).maybe(:array)   # equal split: array of user IDs
        optional(:user_shares).maybe(:array) # non-equal splits: array of { user_id:, share: }
        optional(:split_method).maybe(:string)
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
        key.failure("is required") if value.nil?
      end

      rule(:category_id) do
        next if values[:transaction_type] == "transfer"
        key.failure("is required") if value.nil?
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

      # --- paid_by and split_method: required for any shared expense ---

      rule(:paid_by) do
        is_shared = values[:transaction_type] == "expense" &&
                    (values[:shared_by]&.any? || values[:user_shares]&.any?)
        next unless is_shared
        key.failure("is required for shared expense") if value.nil?
      end

      rule(:split_method) do
        is_shared = values[:transaction_type] == "expense" &&
                    (values[:shared_by]&.any? || values[:user_shares]&.any?)
        next unless is_shared
        key.failure("is required for shared expense") if value.nil?
        next if value.nil?
        key.failure("must be one of: #{SUPPORTED_SPLITS.join(', ')}") unless SUPPORTED_SPLITS.include?(value)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      if transfer?
        yield find_from_account
        yield find_to_account
      elsif shared_expense?
        yield find_paid_by_user
        yield find_account_for_payer
        yield find_category_for_payer
        yield(equal_shared? ? find_shared_by_users : find_user_shares_users)
      else
        yield find_account
        yield find_category
      end
      yield find_currency
      yield persist

      Success(
        success: true,
        transaction: Api::V0::TransactionSerializer.render_as_hash(transaction)
      )
    end

    private

    attr_reader :current_user, :params, :account, :from_account, :to_account,
                :category, :currency, :transaction, :paid_by_user, :shared_by_users

    def transfer?
      params[:transaction_type] == "transfer"
    end

    def shared_expense?
      params[:transaction_type] == "expense" &&
        (params[:shared_by].present? || params[:user_shares].present?)
    end

    def equal_shared?
      params[:shared_by].present?
    end

    # --- finders for personal expense ---

    def find_account
      @account = current_user.accounts.find_by(id: params[:account_id])
      @account ? Success() : Failure(:not_found)
    end

    def find_category
      @category = current_user.categories.find_by(id: params[:category_id])
      @category ? Success() : Failure(:not_found)
    end

    # --- finders for transfer ---

    def find_from_account
      @from_account = current_user.accounts.find_by(id: params[:from_account_id])
      @from_account ? Success() : Failure(:not_found)
    end

    def find_to_account
      @to_account = current_user.accounts.find_by(id: params[:to_account_id])
      @to_account ? Success() : Failure(:not_found)
    end

    # --- finders for shared expense ---

    def find_paid_by_user
      @paid_by_user = User.find_by(id: params[:paid_by])
      @paid_by_user ? Success() : Failure(:not_found)
    end

    def find_account_for_payer
      @account = paid_by_user.accounts.find_by(id: params[:account_id])
      @account ? Success() : Failure(:not_found)
    end

    def find_category_for_payer
      @category = paid_by_user.categories.find_by(id: params[:category_id])
      @category ? Success() : Failure(:not_found)
    end

    # Equal split: load User records and validate all IDs exist.
    def find_shared_by_users
      @shared_by_users = User.where(id: params[:shared_by]).to_a
      missing = params[:shared_by] - @shared_by_users.map(&:id)
      missing.empty? ? Success() : Failure(errors: { shared_by: [ "contains unknown user IDs: #{missing.join(', ')}" ] })
    end

    # Non-equal split: validate all user_id values in user_shares exist.
    def find_user_shares_users
      user_ids  = params[:user_shares].map { |s| s[:user_id] }
      found_ids = User.where(id: user_ids).pluck(:id)
      missing   = user_ids - found_ids
      return Failure(errors: { user_shares: [ "contains unknown user IDs: #{missing.join(', ')}" ] }) if missing.any?

      Success()
    end

    # --- currency (all types) ---

    def find_currency
      return Success() unless params[:currency_id]

      @currency = Currency.find_by(id: params[:currency_id])
      @currency ? Success() : Failure(:not_found)
    end

    # --- persistence ---

    def persist
      if transfer?
        persist_transfer
      elsif shared_expense?
        persist_shared_expense
      else
        persist_personal
      end
    end

    def persist_transfer
      result = Transaction::Transfer::Create.call(
        user:             current_user,
        title:            params[:title],
        amount_cents:     params[:amount_cents],
        from_account:     from_account,
        to_account:       to_account,
        transaction_date: parse_date,
        note:             params[:note],
        currency:         currency
      )
      handle_service_result(result)
    end

    def persist_personal
      result = Transaction::Personal::Create.call(
        user:             current_user,
        title:            params[:title],
        transaction_type: params[:transaction_type],
        amount_cents:     params[:amount_cents],
        account:          account,
        category:         category,
        transaction_date: parse_date,
        note:             params[:note],
        currency:         currency
      )
      handle_service_result(result)
    end

    def persist_shared_expense
      base_args = {
        paid_by_user:     paid_by_user,
        split_method:     params[:split_method],
        title:            params[:title],
        amount_cents:     params[:amount_cents],
        account:          account,
        category:         category,
        transaction_date: parse_date,
        note:             params[:note],
        currency:         currency
      }

      extra = if equal_shared?
        { shared_by_users: shared_by_users }
      else
        { user_shares: params[:user_shares].map { |s| s.transform_keys(&:to_sym) } }
      end

      handle_service_result(Transaction::Shared::Create.call(**base_args, **extra))
    end

    def handle_service_result(result)
      if result.success?
        @transaction = result.value!
        Success()
      else
        Failure(errors: result.failure[:errors])
      end
    end

    def parse_date
      params[:transaction_date] ? Time.parse(params[:transaction_date]) : Time.current
    end
  end
end
