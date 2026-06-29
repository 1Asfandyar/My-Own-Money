# Creates the single admin account used to access ActiveAdmin.
admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@rupperally.com')
admin_password = ENV.fetch('ADMIN_PASSWORD', 'password')

if admin_password.blank?
  raise 'Set ADMIN_PASSWORD before seeding production' if Rails.env.production?

  admin_password = 'password'
  warn 'Using development admin password: password'
end

admin = AdminUser.find_or_initialize_by(email: admin_email)

if admin.new_record? || ENV['ADMIN_PASSWORD'].present?
  admin.password = admin_password
  admin.password_confirmation = admin_password
end

admin.save!

extra_admins = AdminUser.where.not(id: admin.id)
warn "There are #{extra_admins.count} extra admin accounts. Remove them manually." if extra_admins.exists?


test_users = []
(1...5).each do |i|
  email = ENV.fetch("TEST_USER_EMAIL_#{i}", "test.user#{i}@rupeerally.com")
  password = ENV.fetch("TEST_USER_PASSWORD_#{i}", "password")
  user = User.find_or_initialize_by(email: email)

  if user.new_record? || password.present?
    user.password = password
    user.password_confirmation = password
    user.onboarding_completed = true
    user.role = "user"
    user.full_name = "Test User #{i}"
    user.mobile_number = "123456789#{i}"
  end

  user.save!
  test_users << user.reload
  Rails.logger.info "Test user ready: #{user.email}"
end

# make every test user friends with each other
test_users.each_with_index do |user_a, index_a|
  test_users[index_a + 1..-1].each do |user_b|
    Friendship.find_or_create_by!(user_a: user_a, user_b: user_b) do |friendship|
      friendship.requested_by = user_a
      friendship.status = :accepted
    end
  end
end

# create a group for all test users
group = Group.find_or_create_by!(name: "Test Group", created_by: test_users.first) do |g|
  g.description = "A group for testing purposes"
end

test_users.each do |user|
  GroupsUser.find_or_create_by!(group: group, user: user)
end

Rails.logger.info "Admin user ready: #{admin.email}"
Rails.logger.info "Test users ready: #{test_users.map(&:email).join(', ')}"
Rails.logger.info "Test group ready: #{group.name}"
