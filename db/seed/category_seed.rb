(1...5).each do |i|
  email = ENV.fetch("TEST_USER_EMAIL_#{i}", "test.user#{i}@rupeerally.com")
  user = User.find_by(email: email)
  if user && !user.categories.exists?
    Categories::AssignDefaults.call(user)
  end
  Rails.logger.info "Seeded categories. Total count: #{user.categories.count}"
end
