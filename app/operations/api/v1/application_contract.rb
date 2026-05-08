require "dry/validation"

module Api
  module V1
    class ApplicationContract < Dry::Validation::Contract
      config.messages.backend = :i18n

      register_macro(:email_format) do
        regexp = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
        key.failure("must be a valid email") if key? && value.present? && !regexp.match?(value)
      end
    end
  end
end
