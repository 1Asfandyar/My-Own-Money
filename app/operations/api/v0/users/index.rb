module Api::V0::Users
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:query).maybe(:string)
      end
    end

    def call(params, current_user:)
      params = yield validate_contract(params.slice(:query))
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
      scope = User.all.order(created_at: :desc)
      return scope if params[:query].blank?

      scope.where("email ILIKE :query", query: "%#{params[:query]}%")
    end
  end
end
