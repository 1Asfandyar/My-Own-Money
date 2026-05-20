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
  Rails.logger.info "Test user ready: #{user.email}"
end

Rails.logger.info "Admin user ready: #{admin.email}"
