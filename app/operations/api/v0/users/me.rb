module Api::V0::Users
  class Me
    include Api::V0::ApplicationOperation

    def call(_params = {}, current_user:)
      Success(
        success: true,
        user: Api::V0::UserSerializer.render_as_hash(current_user)
      )
    end
  end
end
