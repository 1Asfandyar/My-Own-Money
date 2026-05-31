module Notifications
  class Send < ApplicationService
    def call(user:, title:, body:, data: {})
      tokens = user.device_tokens.pluck(:token)
      return Success(:no_tokens) if tokens.empty?

      app = Rpush::Fcm::App.find_by(name: "rupeerally")
      return Failure(:rpush_app_not_configured) unless app

      # rpush FCM creates one notification per device token
      # data values must all be strings per FCM spec
      string_data = data.transform_values(&:to_s)

      tokens.each do |token|
        notification              = Rpush::Fcm::Notification.new
        notification.app          = app
        notification.device_token = token
        notification.notification = { title: title, body: body }
        notification.data         = string_data
        notification.save!
      end

      Success(:enqueued)
    rescue => e
      Failure(e.message)
    end
  end
end
