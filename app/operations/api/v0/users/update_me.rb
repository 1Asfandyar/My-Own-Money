module Api::V0::Users
  class UpdateMe
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:full_name).filled(:string)
        optional(:mobile_number).filled(:string)
        optional(:email).filled(:string)
        optional(:current_password).filled(:string)
        optional(:password).filled(:string)
        optional(:password_confirmation).filled(:string)
        optional(:onboarding_completed).filled(:bool)
      end

      rule(:email).validate(:email_format)
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield validate_current_password
      yield update_user

      Success(
        success: true,
        user: Api::V0::UserSerializer.render_as_hash(current_user)
      )
    end

    private
    attr_reader :params, :current_user

    def user_params
      {
        full_name: params[:full_name],
        mobile_number: params[:mobile_number],
        email: params[:email],
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        onboarding_completed: params[:onboarding_completed]
      }.compact
    end

    def update_user
      current_user.update(user_params) ? Success(current_user) : Failure(errors: current_user.errors.to_hash)
    end

    def validate_current_password
      return Success() unless password_update?
      return Failure(errors: { current_password: [ "is required" ] }) if params[:current_password].blank?
      return Failure(errors: { current_password: [ "is invalid" ] }) unless current_user.valid_password?(params[:current_password])

      Success()
    end

    def password_update?
      params.key?(:password) || params.key?(:password_confirmation)
    end
  end
end
