module Api::V0::Categories
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:include_zero_balance).filled(:bool)
        optional(:category_type).filled(:string)
        optional(:name).filled(:string)
      end

      rule(:category_type) do
        key.failure("must be expense or income") if values[:category_type] && !%w[expense income].include?(values[:category_type])
      end
    end

    def call(params, current_user:)
      @params = params
      @current_user = current_user

      yield authorize?

      Success(
        success: true,
        categories: Api::V0::CategorySerializer.render_as_hash(categories)
      )
    end

    private

    attr_reader :params, :current_user

    def authorize?
      CategoryPolicy.new(current_user, Category).index? ? Success() : Failure(:forbidden)
    end

    def categories
      scope = current_user.categories.order(:category_type, :name, :created_at)
      scope = scope.where(category_type: params[:category_type]) if params[:category_type]
      scope = scope.where("name ILIKE ?", "%#{params[:name]}%") if params[:name]
      scope = scope.where.not(balance_cents: 0) unless params[:include_zero_balance]
      scope
    end
  end
end
