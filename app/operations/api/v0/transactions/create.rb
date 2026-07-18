module Api::V0::Transactions
  class Create
    include Api::V0::ApplicationOperation

    Contract = Api::V0::Contracts::Transactions::Create

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      if transfer?
        yield find_from_account
        yield find_to_account
      elsif settlement?
        yield find_paid_by_user
        yield find_paid_to_user
        yield find_paid_by_account
        yield find_paid_to_account
      else
        # personal expense, income, and shared expense all use current_user's account/category
        yield find_account
        yield find_category
        if shared_expense?
          yield(equal_shared? ? find_shared_by_users : find_user_shares_users)
          yield find_group if params[:group_id].present?
        end
      end
      yield persist

      Success(
        success: true,
        transaction: Api::V0::TransactionSerializer.render_as_hash(transaction)
      )
    end

    private

    attr_reader :current_user, :params, :account, :from_account, :to_account,
          :category, :transaction, :shared_by_users, :paid_to_user, :group,
                :paid_by_user, :paid_by_account, :paid_to_account

    def transfer?
      params[:transaction_type] == "transfer"
    end

    def settlement?
      params[:transaction_type] == "settlement"
    end

    def shared_expense?
      params[:transaction_type] == "expense" &&
        (params[:shared_by].present? || params[:user_shares].present?)
    end

    def equal_shared?
      params[:shared_by].present?
    end

    def find_account
      @account = current_user.accounts.find_by(id: params[:account_id])
      @account ? Success() : Failure(:not_found)
    end

    def find_category
      @category = current_user.categories.find_by(id: params[:category_id])
      @category ? Success() : Failure(:not_found)
    end

    def find_from_account
      @from_account = current_user.accounts.find_by(id: params[:from_account_id])
      @from_account ? Success() : Failure(:not_found)
    end

    def find_to_account
      @to_account = current_user.accounts.find_by(id: params[:to_account_id])
      @to_account ? Success() : Failure(:not_found)
    end

    def find_paid_by_user
      @paid_by_user = User.find_by(id: params[:paid_by_id])
      @paid_by_user ? Success() : Failure(:not_found)
    end

    def find_paid_to_user
      @paid_to_user = User.find_by(id: params[:paid_to_id])
      @paid_to_user ? Success() : Failure(:not_found)
    end

    def find_paid_by_account
      if params[:paid_by_account_id].present?
        @paid_by_account = paid_by_user.accounts.find_by(id: params[:paid_by_account_id])
        return @paid_by_account ? Success() : Failure(:not_found)
      end

      @paid_by_account = paid_by_user.preferred_account
      @paid_by_account ? Success() : Failure(errors: { paid_by_account_id: [ "paid_by user has no accounts" ] })
    end

    def find_paid_to_account
      if params[:paid_to_account_id].present?
        @paid_to_account = paid_to_user.accounts.find_by(id: params[:paid_to_account_id])
        return @paid_to_account ? Success() : Failure(:not_found)
      end

      @paid_to_account = paid_to_user.preferred_account
      @paid_to_account ? Success() : Failure(errors: { paid_to_account_id: [ "paid_to user has no accounts" ] })
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

    def find_group
      @group = Group.find_by(id: params[:group_id])
      return Failure(:not_found) unless @group
      return Failure(:forbidden) unless @group.users.exists?(id: current_user.id)

      Success()
    end

    def persist
      if transfer?
        persist_transfer
      elsif shared_expense?
        persist_shared_expense
      elsif settlement?
        persist_settlement
      else
        persist_personal
      end
    end

    def persist_settlement
      result = Transaction::Settlement::Create.call(
        paid_by_user:     paid_by_user,
        paid_to_user:     paid_to_user,
        title:            params[:title],
        amount_cents:     params[:amount_cents],
        paid_by_account:  paid_by_account,
        paid_to_account:  paid_to_account,
        transaction_date: parse_date,
        note:             params[:note]
      )
      handle_service_result(result)
    end

    def persist_transfer
      result = Transaction::Transfer::Create.call(
        user:             current_user,
        title:            params[:title],
        amount_cents:     params[:amount_cents],
        from_account:     from_account,
        to_account:       to_account,
        transaction_date: parse_date,
        note:             params[:note]
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
        note:             params[:note]
      )
      handle_service_result(result)
    end

    def persist_shared_expense
      handle_service_result(Transaction::Shared::Create.call(**shared_expense_args))
    end

    def shared_expense_args
      base_args = {
        user:             current_user,
        split_method:     params[:split_method],
        title:            params[:title],
        amount_cents:     params[:amount_cents],
        account:          account,
        category:         category,
        transaction_date: parse_date,
        note:             params[:note],
        group:            group
      }

      extra = if equal_shared?
        { shared_by_users: shared_by_users }
      else
        { user_shares: params[:user_shares].map { |s| s.transform_keys(&:to_sym) } }
      end
      base_args.merge(extra)
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
