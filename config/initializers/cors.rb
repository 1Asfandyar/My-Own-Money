# config/initializers/cors.rb
#
# CORS (Cross-Origin Resource Sharing) configuration for the API.
#
# PRODUCTION SETUP:
#   Set the CORS_ALLOWED_ORIGINS environment variable to your frontend domain(s):
#     CORS_ALLOWED_ORIGINS=https://app.yourdomain.com,https://yourdomain.com
#
# WHY expose "Authorization":
#   devise-jwt returns the JWT token in the Authorization response header.
#   Without explicitly exposing it, browsers on cross-origin requests cannot
#   read the header — the client silently receives no token and auth breaks.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ALLOWED_ORIGINS", "localhost:3000,localhost:3001,localhost:8081").split(",").map(&:strip)

    resource "*",
      headers:     :any,
      methods:     %i[get post put patch delete options head],
      expose:      [ "Authorization" ],  # required for devise-jwt token delivery
      credentials: false              # set true only if you use cookie-based auth across origins
  end
end
