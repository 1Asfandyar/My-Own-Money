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
        optional(:currency_id).maybe(:integer)
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
        onboarding_completed: params[:onboarding_completed],
        currency_id: params[:currency_id]
      }.compact
    end

    def validate_current_password
      return Success() unless password_update?
      return Failure(errors: { current_password: [ "is required" ] }) if params[:current_password].blank?
      return Failure(errors: { current_password: [ "is invalid" ] }) unless current_user.valid_password?(params[:current_password])

      Success()
    end

    def update_user
      yield validate_currency
      yield validate_onboarding_currency

      current_user.update(user_params) ? Success(current_user) : Failure(errors: current_user.errors.to_hash)
    end

    def validate_currency
      return Success() unless params.key?(:currency_id)
      return Success() if params[:currency_id].nil?

      Currency.exists?(id: params[:currency_id]) ? Success() : Failure(errors: { currency_id: [ "is invalid" ] })
    end

    def validate_onboarding_currency
      mark_complete = params[:onboarding_completed] == true
      next_currency_id = params.key?(:currency_id) ? params[:currency_id] : current_user.currency_id
      return Success() unless mark_complete
      return Success() if next_currency_id.present?

      Failure(errors: { currency_id: [ "must be present to complete onboarding" ] })
    end

    def password_update?
      params.key?(:password) || params.key?(:password_confirmation)
    end
  end
end
