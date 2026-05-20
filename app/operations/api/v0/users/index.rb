module Api::V0::Users
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:email).filled(:string)
      end

      rule(:email).validate(:email_format)
    end

    def call(params, current_user:)
      params = yield validate_contract(params.slice(:email))
      @current_user = current_user
      @params = params

      yield authorize

      Success(success: true, users: Api::V0::UserSerializer.render_as_hash(filtered_users))
    end

    private

    attr_reader :current_user, :params

    def authorize
      UserPolicy.new(current_user, User).index? ? Success() : Failure(:forbidden)
    end

    def filtered_users
      User.where("LOWER(email) = ?", params[:email].downcase)
    end
  end
end
