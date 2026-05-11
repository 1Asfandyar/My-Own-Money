module Api::V0::Categories
  class Index
    include Api::V0::ApplicationOperation

    def call(_params = {}, current_user:)
      @current_user = current_user

      yield authorize?

      Success(
        success: true,
        categories: Api::V0::CategorySerializer.render_as_hash(categories)
      )
    end

    private

    attr_reader :current_user

    def authorize?
      CategoryPolicy.new(current_user, Category).index? ? Success() : Failure(:forbidden)
    end

    def categories
      current_user.categories.order(created_at: :desc)
    end
  end
end
