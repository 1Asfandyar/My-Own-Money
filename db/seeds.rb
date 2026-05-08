# Creates the single admin account used to access ActiveAdmin.
admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
admin_password = ENV['ADMIN_PASSWORD']

if admin_password.blank?
  raise 'Set ADMIN_PASSWORD before seeding production' if Rails.env.production?

  admin_password = 'ChangeMe123!'
  warn 'Using development admin password: ChangeMe123!'
end

admin = AdminUser.find_or_initialize_by(email: admin_email)

if admin.new_record? || ENV['ADMIN_PASSWORD'].present?
  admin.password = admin_password
  admin.password_confirmation = admin_password
end

admin.save!

extra_admins = AdminUser.where.not(id: admin.id)
warn "There are #{extra_admins.count} extra admin accounts. Remove them manually." if extra_admins.exists?

Rails.logger.debug "Admin user ready: #{admin.email}"
