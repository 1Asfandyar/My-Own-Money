module Api::V0::Currencies
  class Index
    include Api::V0::ApplicationOperation

    def call(_params = {}, current_user:)
      @current_user = current_user
      yield authorize

      Success(
        success: true,
        currencies: Api::V0::CurrencySerializer.render_as_hash(currencies)
      )
    end

    private

    attr_reader :current_user

    def authorize
      CurrencyPolicy.new(current_user, Currency).index? ? Success() : Failure(:forbidden)
    end

    def currencies
      Currency.order(:code)
    end
  end
end
