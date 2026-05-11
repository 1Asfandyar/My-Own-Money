module Api::V0::Categories
  class Create
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:name).filled(:string)
        required(:category_type).filled(:string)
      end

      rule(:category_type) do
        key.failure("must be expense or income") unless %w[expense income].include?(value)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield authorize?
      yield persist

      Success(
        success: true,
        category: Api::V0::CategorySerializer.render_as_hash(category)
      )
    end

    private

    attr_reader :current_user, :params, :category

    def authorize?
      CategoryPolicy.new(current_user, Category.new).create? ? Success() : Failure(:forbidden)
    end

    def persist
      @category = Category.new(category_params)
      category.save ? Success(category) : Failure(errors: category.errors.to_hash)
    end

    def category_params
      params.slice(:name, :category_type).merge(user: current_user)
    end
  end
end
