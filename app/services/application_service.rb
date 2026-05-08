require "dry/monads"

class ApplicationService
  include Dry::Monads[:result]

  def self.call(...)
    new.call(...)
  end
end
