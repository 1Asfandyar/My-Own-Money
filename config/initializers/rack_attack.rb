# config/initializers/rack_attack.rb
#
# Rack::Attack provides IP-level rate limiting and brute-force protection.
# It runs as Rack middleware — before Rails routing — so it's extremely cheap.
#
# CACHE REQUIREMENT:
#   Rack::Attack uses Rails.cache by default to track request counts.
#   In production, configure a real shared cache (Redis or Solid Cache) so
#   rate limits are enforced consistently across multiple Puma workers/servers.
#   With :memory_store each worker process has its own counter (not shared).
#
# MONITORING:
#   Subscribe to the ActiveSupport notification to log throttled requests:
#     ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
#       Rails.logger.warn "[Rack::Attack] Throttled: #{payload[:request].ip}"
#     end

module Rack
  class Attack
    # ── Safelists ───────────────────────────────────────────────────────────

    # Always allow Kamal/load-balancer health checks through.
    safelist("allow health check") do |req|
      req.path == "/up"
    end

    # ── Throttles ────────────────────────────────────────────────────────────

    # Limit authentication attempts per IP to prevent brute-force.
    # 5 attempts / 1 minute is strict but necessary for auth endpoints.
    throttle("api/auth", limit: 5, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/api/v0/auth") && req.post?
    end

    # Throttle admin login attempts separately (lower limit, shorter window).
    throttle("admin/login", limit: 10, period: 5.minutes) do |req|
      req.ip if req.path == "/admin/login" && req.post?
    end

    # General API traffic per IP — prevents scrapers and runaway clients.
    # 300 requests / 5 minutes = 1 req/second sustained is generous for a mobile API.
    throttle("api/ip", limit: 300, period: 5.minutes) do |req|
      req.ip if req.path.start_with?("/api/")
    end

    # ── Response for throttled requests ──────────────────────────────────────

    # Return JSON 429 so API clients get a machine-readable error.
    self.throttled_responder = lambda do |env|
      retry_after = (env["rack.attack.match_data"] || {})[:period]
      [
        429,
        {
          "Content-Type"  => "application/json",
          "Retry-After"   => retry_after.to_s
        },
        [ { error: "Rate limit exceeded. Please retry later.", retry_after: retry_after }.to_json ]
      ]
    end
  end
end
