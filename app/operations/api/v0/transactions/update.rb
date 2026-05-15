module Api::V0::Transactions
  class Update
    include Api::V0::ApplicationOperation

    Contract = Api::V0::Contracts::Transactions::Update

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield find_transaction

      if shared_expense?
        yield validate_split_method_change
        yield validate_exact_split_sum if exact_split_with_user_shares?
        yield find_paid_by_user        if params.key?(:paid_by)
        yield find_account_for_payer   if params.key?(:account_id)
        yield find_category_for_payer  if params.key?(:category_id)
        yield find_split_participants  if split_participants_provided?
        yield find_currency            if params.key?(:currency_id)
        yield persist_shared
      else
        yield find_account     if params.key?(:account_id)
        yield find_from_account if params.key?(:from_account_id)
        yield find_to_account   if params.key?(:to_account_id)
        yield find_category    if params.key?(:category_id)
        yield find_currency    if params.key?(:currency_id)
        yield validate_transfer_params if transfer_effective?
        yield persist_personal_or_transfer
      end

      Success(
        success: true,
        transaction: Api::V0::TransactionSerializer.render_as_hash(transaction)
      )
    end

    private

    attr_reader :current_user, :params, :transaction, :account,
                :from_account, :to_account, :category, :currency,
                :paid_by_user, :shared_by_users

    # --- type helpers ---

    def shared_expense?
      transaction.shared?
    end

    def transfer_effective?
      (params[:transaction_type] || transaction.transaction_type).to_sym == :transfer
    end

    # --- shared expense helpers ---

    def effective_payer
      @paid_by_user || transaction.user
    end

    def effective_split_method
      params[:split_method] || transaction.transaction_splits.first&.split_method.to_s
    end

    def equal_split?
      effective_split_method == "equal"
    end

    def split_participants_provided?
      params[:shared_by].present? || params[:user_shares].present?
    end

    def exact_split_with_user_shares?
      effective_split_method == "exact" && params[:user_shares].present?
    end

    # --- shared expense validations ---

    # When the split method changes, participants must be explicitly provided
    # because the old allocation_value data cannot be reliably converted.
    def validate_split_method_change
      return Success() unless params.key?(:split_method) && params[:split_method].present?

      old_method = transaction.transaction_splits.first&.split_method.to_s
      return Success() if params[:split_method] == old_method

      if equal_split? && !params[:shared_by].present?
        return Failure(errors: { shared_by: [ "is required when changing to equal split" ] })
      elsif !equal_split? && !params[:user_shares].present?
        return Failure(errors: { user_shares: [ "is required when changing split method" ] })
      end

      Success()
    end

    # Contract cannot check exact-split sums without knowing the effective amount,
    # so this operation-level step validates it against the transaction's current amount.
    def validate_exact_split_sum
      effective_amount = params[:amount_cents] || transaction.amount_cents
      total = params[:user_shares].sum { |s| s[:share] }
      return Failure(errors: { user_shares: [ "shares must sum to #{effective_amount} for exact split" ] }) unless total == effective_amount

      Success()
    end

    # --- finders for shared expense ---

    def find_paid_by_user
      @paid_by_user = User.find_by(id: params[:paid_by])
      @paid_by_user ? Success() : Failure(:not_found)
    end

    # Account must belong to the effective payer (new or existing).
    def find_account_for_payer
      @account = effective_payer.accounts.find_by(id: params[:account_id])
      @account ? Success() : Failure(:not_found)
    end

    def find_category_for_payer
      @category = effective_payer.categories.find_by(id: params[:category_id])
      @category ? Success() : Failure(:not_found)
    end

    def find_split_participants
      equal_split? ? find_shared_by_users : find_user_shares_users
    end

    def find_shared_by_users
      @shared_by_users = User.where(id: params[:shared_by]).to_a
      missing = params[:shared_by] - @shared_by_users.map(&:id)
      missing.empty? ? Success() : Failure(errors: { shared_by: [ "contains unknown user IDs: #{missing.join(', ')}" ] })
    end

    def find_user_shares_users
      user_ids  = params[:user_shares].map { |s| s[:user_id] }
      found_ids = User.where(id: user_ids).pluck(:id)
      missing   = user_ids - found_ids
      return Failure(errors: { user_shares: [ "contains unknown user IDs: #{missing.join(', ')}" ] }) if missing.any?

      Success()
    end

    # --- finders for personal / transfer ---

    def find_account
      return Success() unless params.key?(:account_id)
      @account = current_user.accounts.find_by(id: params[:account_id])
      @account ? Success() : Failure(:not_found)
    end

    def find_from_account
      return Success() unless params.key?(:from_account_id)
      @from_account = current_user.accounts.find_by(id: params[:from_account_id])
      @from_account ? Success() : Failure(:not_found)
    end

    def find_to_account
      return Success() unless params.key?(:to_account_id)
      @to_account = current_user.accounts.find_by(id: params[:to_account_id])
      @to_account ? Success() : Failure(:not_found)
    end

    def find_category
      return Success() unless params.key?(:category_id)
      @category = current_user.categories.find_by(id: params[:category_id])
      @category ? Success() : Failure(:not_found)
    end

    def find_transaction
      @transaction = current_user.transactions.find_by(id: params[:id])
      @transaction ? Success() : Failure(:not_found)
    end

    def find_currency
      return Success() unless params.key?(:currency_id)
      @currency = Currency.find_by(id: params[:currency_id])
      @currency ? Success() : Failure(:not_found)
    end

    # --- transfer validation ---

    def validate_transfer_params
      effective_to_account = to_account || transaction.transfer_account
      return Failure(errors: { to_account_id: [ "is required for transfer" ] }) if effective_to_account.nil?

      effective_from_id = (from_account || transaction.account).id
      return Failure(errors: { to_account_id: [ "must be different from from_account_id" ] }) if effective_from_id == effective_to_account.id

      Success()
    end

    # --- persistence ---

    def persist_shared
      service_args = {
        transaction:  transaction,
        paid_by_user: effective_payer,
        split_method: effective_split_method,
        amount_cents: params[:amount_cents] || transaction.amount_cents,
        account:      account || transaction.account,
        category:     category || transaction.category
      }

      service_args[:title]            = params[:title]                        if params.key?(:title)
      service_args[:transaction_date] = Time.parse(params[:transaction_date]) if params.key?(:transaction_date)
      service_args[:note]             = params[:note]                         if params.key?(:note)
      service_args[:currency]         = currency                              if currency

      if split_participants_provided?
        if equal_split?
          service_args[:shared_by_users] = shared_by_users
        else
          service_args[:user_shares] = params[:user_shares].map { |s| s.transform_keys(&:to_sym) }
        end
      end

      handle_service_result(Transaction::Shared::Update.call(**service_args))
    end

    def persist_personal_or_transfer
      if transaction.transfer? || transfer_effective?
        update_as_transfer
      else
        update_as_personal
      end
    end

    def update_as_transfer
      service_attrs = build_common_attrs
      service_attrs[:from_account] = from_account if from_account
      service_attrs[:to_account]   = to_account   if to_account

      handle_service_result(Transaction::Transfer::Update.call(transaction: transaction, **service_attrs))
    end

    def update_as_personal
      service_attrs = build_common_attrs
      service_attrs[:account] = account if account

      handle_service_result(Transaction::Personal::Update.call(transaction: transaction, **service_attrs))
    end

    def build_common_attrs
      attrs = {}
      attrs[:title]            = params[:title]                        if params.key?(:title)
      attrs[:transaction_type] = params[:transaction_type]             if params.key?(:transaction_type)
      attrs[:amount_cents]     = params[:amount_cents]                 if params.key?(:amount_cents)
      attrs[:category]         = category                              if category
      attrs[:currency]         = currency                              if currency
      attrs[:transaction_date] = Time.parse(params[:transaction_date]) if params.key?(:transaction_date)
      attrs[:note]             = params[:note]                         if params.key?(:note)
      attrs
    end

    def handle_service_result(result)
      if result.success?
        @transaction = result.value!
        Success()
      else
        Failure(errors: result.failure[:errors])
      end
    end
  end
end
