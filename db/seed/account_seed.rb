currency = Currency.find_by(code: 'USD')
(1...5).each do |i|
  email = ENV.fetch("TEST_USER_EMAIL_#{i}", "test.user#{i}@rupeerally.com")
  user = User.find_by(email: email)
  if user && !user.accounts.exists?
    Account.create!(user: user, name: "Default Account #{i}", currency: currency)
  end
end
