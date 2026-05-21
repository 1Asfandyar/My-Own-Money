module Api::V0::Categories
  class Summary
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:account_id).value(:integer)
        optional(:category_id).maybe(:integer)
      end
    end

    def call(params, current_user:)
      @params = params
      @current_user = current_user

      yield authorize?

      Success(Api::V0::Categories::PersonalSummaryService.new(current_user, params).call)
    end

    private

    attr_reader :current_user, :params

    def authorize?
      CategoryPolicy.new(current_user, Category).index? ? Success() : Failure(:forbidden)
    end
  end
end
