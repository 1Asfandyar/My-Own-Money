module Api::V0::Accounts
  class Index
    include Api::V0::ApplicationOperation

    def call(_params = {}, current_user:)
      @current_user = current_user

      yield authorize

      Success(
        success: true,
        accounts: Api::V0::AccountSerializer.render_as_hash(accounts)
      )
    end

    private

    attr_reader :current_user

    def authorize
      AccountPolicy.new(current_user, Account).index? ? Success() : Failure(:forbidden)
    end

    def accounts
      current_user.accounts.order(created_at: :desc)
    end
  end
end
