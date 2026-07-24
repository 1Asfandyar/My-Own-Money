class MoveCurrencyToUsersOnly < ActiveRecord::Migration[8.1]
  def up
    add_reference :users, :currency, foreign_key: true

    usd_id = select_value("SELECT id FROM currencies WHERE code = 'USD' LIMIT 1")
    fallback_currency_id = usd_id || select_value("SELECT id FROM currencies ORDER BY id ASC LIMIT 1")

    execute <<~SQL
      UPDATE users
      SET currency_id = COALESCE(
        (
          SELECT a.currency_id
          FROM accounts a
          WHERE a.user_id = users.id
          ORDER BY a.id ASC
          LIMIT 1
        ),
        (
          SELECT t.currency_id
          FROM transactions t
          WHERE t.user_id = users.id
          ORDER BY t.id ASC
          LIMIT 1
        ),
        #{fallback_currency_id || 'NULL'}
      )
      WHERE users.currency_id IS NULL;
    SQL

    remove_reference :accounts, :currency, foreign_key: true
    remove_reference :transactions, :currency, foreign_key: true
  end

  def down
    add_reference :accounts, :currency, null: false, foreign_key: true
    add_reference :transactions, :currency, null: false, foreign_key: true

    execute <<~SQL
      UPDATE accounts
      SET currency_id = users.currency_id
      FROM users
      WHERE accounts.user_id = users.id;
    SQL

    execute <<~SQL
      UPDATE transactions
      SET currency_id = users.currency_id
      FROM users
      WHERE transactions.user_id = users.id;
    SQL

    remove_reference :users, :currency, foreign_key: true
  end
end