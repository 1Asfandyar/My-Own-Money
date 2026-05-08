# RupeeRally — Scenarios & Money Division Logic

## Core Rules

- `transactions.amount` = full amount paid
- `transaction_splits.owed_amount` = each user's share (used for expense reports)
- `debts` = net current balance between two users (pre-calculated, not derived)
- Only one debt row per user pair — always net the balance before saving

---

## Transaction Types & When to Use Each

| Type       | visibility_type | Has splits? | Updates debts? |
|------------|-----------------|-------------|----------------|
| expense    | personal        | no          | no             |
| expense    | shared          | yes         | yes            |
| income     | personal        | no          | no             |
| transfer   | personal        | no          | no             |
| settlement | personal        | no          | yes (reduces)  |

---

## Split Methods

### Equal
Total divided evenly. `allocation_value` not required.

```
Total = 3000, 3 users
Each owed_amount = 1000
```

### Percentage
`allocation_value` = percentage (must sum to 100).

```
Total = 10000
Ahmed: allocation_value=50 → owed_amount=5000
Ali:   allocation_value=30 → owed_amount=3000
Sara:  allocation_value=20 → owed_amount=2000
```

### Shares
`allocation_value` = share count.

```
Total = 12000, total shares = 6
Ahmed: allocation_value=1 → owed_amount = (1/6)*12000 = 2000
Ali:   allocation_value=2 → owed_amount = (2/6)*12000 = 4000
Sara:  allocation_value=3 → owed_amount = (3/6)*12000 = 6000
```

### Exact
`owed_amount` entered directly. `allocation_value` may equal `owed_amount` or be omitted.

```
Total = 12000
Ahmed: owed_amount=2500
Ali:   owed_amount=5000
Sara:  owed_amount=4500
```

---

## Debt Calculation After Shared Expense

Payer is owed by everyone else for their share.

```
Ahmed pays 3000 (shared, equal 3-way)
Splits: Ahmed=1000, Ali=1000, Sara=1000

Debts created:
  Ali  → Ahmed: 1000
  Sara → Ahmed: 1000

Ahmed's own share (1000) is already his — no self-debt.
```

**Algorithm:**
1. For each split where `user != payer`: `payer is owed split.owed_amount by that user`
2. Net the new amount against any existing debt row between that pair
3. If net = 0 → delete the debt row
4. If direction flips → swap `from_user_id` / `to_user_id` and save positive amount

### Netting Example
```
Existing: Ali → Ahmed = 500
New shared expense: Ahmed owes Ali 800

Net: Ahmed → Ali = 300   (direction flipped, old row updated/replaced)
```

---

## Settlement Creation

Ali pays Ahmed 1000 back.

```
transaction: { type: settlement, user_id: Ali, amount: 1000 }

Debt update:
  Find debt where from_user=Ali, to_user=Ahmed
  amount -= 1000
  if amount == 0 → delete row
  if amount < 0  → flip direction, save absolute value
```

---

## Shared Expense Update

Never overwrite debts directly. Reverse then reapply.

```
1. Load old transaction_splits
2. Reverse the debt changes from old splits
3. Delete old splits
4. Create new splits with updated amounts
5. Apply new debt changes
```

---

## Reporting Rules

For expense reports, **always use `transaction_splits.owed_amount`**, not `transactions.amount`.

```
Ahmed pays 3000 dinner (shared, equal 3-way)

Report shows:
  Ahmed expense = 1000  ← his split
  Ali   expense = 1000  ← his split
  Sara  expense = 1000  ← her split

NOT: Ahmed expense = 3000
```

Query pattern:
```ruby
# User's total shared expenses for a period
TransactionSplit
  .joins(:transaction)
  .where(user_id: user.id, transactions: { transaction_type: :expense })
  .sum(:owed_amount)
```

---

## Service Objects (no callbacks)

| Service                         | Responsibility                                          |
|---------------------------------|---------------------------------------------------------|
| `Transactions::CreateExpense`   | Create transaction + splits + update debts              |
| `Transactions::UpdateExpense`   | Reverse old debts, delete old splits, apply new         |
| `Transactions::CreateSettlement`| Create settlement transaction + reduce/delete debt row  |
| `Debts::UpdateBalances`         | Net and persist debt changes for a user pair            |
