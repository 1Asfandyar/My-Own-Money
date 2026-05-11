module Api::V0::Categories
  class Update
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
        optional(:name).maybe(:string)
      end

      rule(:category_type) do
        next unless key? && value
        key.failure("must be expense or income") unless %w[expense income].include?(value)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      @category = current_user.categories.find_by(id: params[:id])
      return Failure(:not_found) unless category

      yield authorize?
      yield persist

      Success(
        success: true,
        category: Api::V0::CategorySerializer.render_as_hash(category)
      )
    end

    private

    attr_reader :params, :current_user, :category

    def authorize?
      CategoryPolicy.new(current_user, category).update? ? Success() : Failure(:forbidden)
    end

    def persist
      category.update(category_params) ? Success(category) : Failure(errors: category.errors.to_hash)
    end

    def category_params
      params.slice(:name).compact
    end
  end
end
