module CategorySeed
  module_function

  def seed!
    User.find_each do |user|
      Categories::AssignDefaults.call(user)
    end

    Rails.logger.info "Assigned default categories to #{User.count} users"
  end
end
