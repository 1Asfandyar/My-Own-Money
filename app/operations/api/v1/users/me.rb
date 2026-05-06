module Api
  module V1
    module Users
      class Me
        include Api::V1::ApplicationOperation

        def call(_params = {}, current_user:)
          Success(
            success: true,
            user: Api::V1::UserSerializer.render_as_hash(current_user, view: :show)
          )
        end
      end
    end
  end
end
