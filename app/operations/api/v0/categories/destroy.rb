module Api::V0::Categories
  class Destroy
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user
      @category     = current_user.categories.find_by(id: params[:id])

      return Failure(:not_found) unless category

      category.destroy

      Success(success: true)
    end

    private

    attr_reader :current_user, :category
  end
end
