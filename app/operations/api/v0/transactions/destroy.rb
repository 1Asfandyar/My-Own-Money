module Api::V0::Transactions
  class Destroy
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield find_transaction
      yield execute

      Success(success: true)
    end

    private

    attr_reader :current_user, :params, :transaction

    def find_transaction
      @transaction = current_user.transactions.find_by(id: params[:id])
      @transaction ? Success() : Failure(:not_found)
    end

    def execute
      result = if transaction.transfer?
        Transaction::Transfer::Destroy.call(transaction: transaction)
      elsif transaction.settlement?
        Transaction::Settlement::Destroy.call(transaction: transaction)
      elsif transaction.shared?
        Transaction::Shared::Destroy.call(transaction: transaction)
      else
        Transaction::Personal::Destroy.call(transaction: transaction)
      end
      result.success? ? Success() : Failure(errors: result.failure[:errors])
    end
  end
end
