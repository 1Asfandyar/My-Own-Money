module Api::V0::Transactions
  class Show
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      txn = current_user.visible_transactions
                        .includes(
                          :user, :account, :category, :currency, :group,
                          :settles_user, :transfer_account,
                          transaction_splits: [ :user, :category ]
                        )
                        .find_by(id: params[:id])

      return Failure(:not_found) unless txn

      yield authorize?(txn)

      formatted = yield Transaction::Formatter.call([ txn ], current_user_id: current_user.id)
      Success(success: true, transaction: formatted.first)
    end

    private

    attr_reader :current_user, :params

    def authorize?(txn)
      TransactionPolicy.new(current_user, txn).show? ? Success() : Failure(:forbidden)
    end
  end
end
