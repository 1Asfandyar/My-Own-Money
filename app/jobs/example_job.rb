class ExampleJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  # Enqueue from console:
  #   ExampleJob.perform_later(user_id: 1)
  #   ExampleJob.set(wait: 10.seconds).perform_later(user_id: 1)
  def perform(user_id:)
    user = User.find(user_id)
    Rails.logger.info("[ExampleJob] running for user=#{user.id} (#{user.email})")
  end
end
