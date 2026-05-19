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

  def revert_account_balance(account:, transaction_type:, amount_cents:)
    case transaction_type.to_sym
    when :income
      account.current_balance_cents -= amount_cents
    when :expense
      account.current_balance_cents += amount_cents
    else
      raise ArgumentError, "Invalid transaction type"
    end
    account.save!
  end

  def update_transfer_balance(from_account:, to_account:, amount_cents:)
    from_account.current_balance_cents -= amount_cents
    from_account.save!
    to_account.current_balance_cents += amount_cents
    to_account.save!
  end

  def revert_transfer_balance(from_account:, to_account:, amount_cents:)
    from_account.current_balance_cents += amount_cents
    from_account.save!
    to_account.current_balance_cents -= amount_cents
    to_account.save!
  end

  def update_category_balance(category:, amount_cents:)
    return unless category
    new_balance = category.balance_cents + amount_cents
    category.update!(balance_cents: new_balance)
  end

  def revert_category_balance(category:, amount_cents:)
    return unless category
    new_balance = category.balance_cents - amount_cents
    category.update!(balance_cents: new_balance)
  end
end
