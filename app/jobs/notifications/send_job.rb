module Notifications
  class SendJob < ApplicationJob
    queue_as :default

    def perform(user_id:, title:, body:, data: {})
      user = User.find(user_id)
      Notifications::Send.call(user: user, title: title, body: body, data: data)
    end
  end
end
