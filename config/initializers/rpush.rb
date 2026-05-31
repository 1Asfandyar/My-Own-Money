Rpush.configure do |config|
  config.client    = :active_record
  config.push_poll = 2
  config.logger    = Rails.logger
end

# Bootstrap the FCM app record on startup (idempotent).
# Requires FCM_PROJECT_ID and FCM_JSON_KEY env vars.
Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.table_exists?("rpush_apps")
  next if Rpush::Fcm::App.exists?(name: "rupeerally")

  app                      = Rpush::Fcm::App.new
  app.name                 = "rupeerally"
  app.firebase_project_id  = ENV.fetch("FCM_PROJECT_ID")
  app.json_key             = ENV.fetch("FCM_JSON_KEY")
  app.connections          = 1
  app.save!
rescue => e
  Rails.logger.error("[rpush] Failed to bootstrap FCM app: #{e.message}")
end
