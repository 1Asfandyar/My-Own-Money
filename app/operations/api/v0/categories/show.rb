module Api::V0::Categories
  class Show
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      @current_user = current_user
      @category     = current_user.categories.find_by(id: params[:id])

      return Failure(:not_found) unless category

      yield authorize?

      Success(
        success: true,
        category: Api::V0::CategorySerializer.render_as_hash(category)
      )
    end

    private

    attr_reader :current_user, :category

    def authorize?
      CategoryPolicy.new(current_user, category).show? ? Success() : Failure(:forbidden)
    end
  end
end
