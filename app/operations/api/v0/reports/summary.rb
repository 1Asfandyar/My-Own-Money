module Api::V0::Reports
  class Summary
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:month).maybe(:string)
      end

      rule(:month) do
        next if value.nil?
        key.failure("must be in YYYY-MM format") unless value.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield authorize?

      Success(
        success: true,
        report: ::Reports::MonthlySummary.new(current_user, params[:month]).call
      )
    end

    private

    attr_reader :current_user, :params

    def authorize?
      current_user.present? ? Success() : Failure(:forbidden)
    end
  end
end
