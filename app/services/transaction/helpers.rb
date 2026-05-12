module Transaction::Helpers
  def update_account_balance(account:, transaction_type:, amount_cents:)
    case transaction_type.to_sym
    when :income
      account.current_balance_cents += amount_cents
    when :expense
      account.current_balance_cents -= amount_cents
    else
      raise ArgumentError, "Invalid transaction type"
    end
    account.save!
  end
end
