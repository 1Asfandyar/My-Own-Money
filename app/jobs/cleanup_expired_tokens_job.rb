class CleanupExpiredTokensJob < ApplicationJob
  queue_as :background

  def perform
    deleted = JwtBlacklist.where("exp < ?", Time.current).delete_all
    Rails.logger.info("[CleanupExpiredTokensJob] Deleted #{deleted} expired JWT blacklist entries")
  end
end
