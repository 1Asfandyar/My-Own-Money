# Transaction Response Format

Unified JSON shape for all transaction types. The backend resolves every
perspective-aware field based on `current_user` — the frontend reads fields
and renders, with no business logic required.

---

## Design Principles

- One JSON shape for all 7 scenarios (shared payer, shared participant,
  personal expense, personal income, transfer, settlement settler,
  settlement settlee)
- All "you vs name" decisions made server-side via `is_you`
- `render_as` tells the frontend exactly which screen/component to open
- `summary` drives list-row rendering; `paid_by` + `splits` drive detail view
- Null fields always present so the frontend shape is predictable

---

## Full Schema

```jsonc
{
  // ── Core identity ────────────────────────────────────────────────────────
  "id": integer,
  "type": "expense | income | transfer | settlement",
  "visibility": "personal | shared",
  "title": string,
  "note": string | null,
  "date": "ISO8601",

  // ── Money ────────────────────────────────────────────────────────────────
  "currency": { "code": string, "symbol": string },
  "amount_cents": integer,         // always the full transaction amount

  // ── Routing hint ─────────────────────────────────────────────────────────
  // Composite key — frontend maps this directly to a screen/component.
  // Derived from type + visibility + viewer_role. Never compute it in the
  // frontend; read it here.
  "render_as": "personal_expense | personal_income | transfer |
                shared_expense_payer | shared_expense_participant |
                settlement_settler | settlement_settlee",

  // ── Viewer perspective ───────────────────────────────────────────────────
  "viewer_role": "owner | payer | participant | settler | settlee",

  // ── List-row data (right side of a transaction list item) ────────────────
  "summary": {
    "label": string,               // ready-to-display — see label table below
    "amount_cents": integer,       // the amount shown next to the label
    "paid_by_label": string        // "You" | "{name}" — for the secondary line
  },

  // ── Detail-view: who paid ─────────────────────────────────────────────────
  "paid_by": {
    "id": integer,
    "name": string,
    "is_you": boolean              // true → "You paid"; false → "{name} paid"
  },

  // ── Accounts ─────────────────────────────────────────────────────────────
  "account": { "id": integer, "name": string },
  "transfer_to_account": { "id": integer, "name": string } | null,
                                   // non-null only for type = transfer

  // ── Category ─────────────────────────────────────────────────────────────
  // null for transfers.
  // For shared expense: payer's category (group-visible display).
  // Viewer's personal category lives inside splits[].category.
  "category": { "id": integer, "name": string } | null,

  // ── Settlement counterpart ───────────────────────────────────────────────
  // Non-null only for type = settlement.
  // Always the *other* party from the viewer's perspective:
  //   settler view  → the person you paid back (settles_user)
  //   settlee view  → the person who paid you  (transaction.user)
  "counterpart": { "id": integer, "name": string } | null,

  // ── Shared split info ────────────────────────────────────────────────────
  // Non-null only when visibility = shared AND type = expense.
  // split_method is transaction-level (all splits in one transaction share
  // the same method).
  "split_method": "equal | percentage | shares | exact" | null,

  // Each entry mirrors one transaction_splits row.
  // Order: viewer's split first, then others sorted by name.
  "splits": [
    {
      "user": { "id": integer, "name": string, "is_you": boolean },
      "owed_amount_cents": integer,

      // Raw allocation input — use to show "how was this split" in detail.
      //   equal   → null
      //   exact   → null (owed_amount_cents IS the input)
      //   %       → e.g. 33.33
      //   shares  → e.g. 2
      "allocation_value": decimal | null,

      // Participant's personal category for this split.
      // null for non-payer participants until they assign it.
      "category": { "id": integer, "name": string } | null
    }
  ] | null
}
```

---

## render_as Values

| render_as                    | When                                             |
|------------------------------|--------------------------------------------------|
| `personal_expense`           | type=expense, visibility=personal                |
| `personal_income`            | type=income, visibility=personal                 |
| `transfer`                   | type=transfer                                    |
| `shared_expense_payer`       | type=expense, visibility=shared, viewer=payer    |
| `shared_expense_participant` | type=expense, visibility=shared, viewer≠payer    |
| `settlement_settler`         | type=settlement, current_user=transaction.user   |
| `settlement_settlee`         | type=settlement, current_user=settles_user       |

---

## summary.label Values

| render_as                    | summary.label      | summary.amount_cents                  |
|------------------------------|--------------------|---------------------------------------|
| `personal_expense`           | "you paid"         | `amount_cents`                        |
| `personal_income`            | "you received"     | `amount_cents`                        |
| `transfer`                   | "you transferred"  | `amount_cents`                        |
| `shared_expense_payer`       | "you lent"         | `amount_cents − viewer's split`       |
| `shared_expense_participant` | "you owe"          | viewer's `owed_amount_cents`          |
| `settlement_settler`         | "you paid back"    | `amount_cents`                        |
| `settlement_settlee`         | "you received"     | `amount_cents`                        |

> **shared_expense_payer:** `summary.amount_cents` = total lent to others
> = `amount_cents − splits.find(is_you).owed_amount_cents`

---

## Backend: Building the Response

### Step 1 — Determine viewer_role

```ruby
def viewer_role(transaction, current_user)
  if transaction.shared? && transaction.expense?
    transaction.user_id == current_user.id ? :payer : :participant
  elsif transaction.settlement?
    transaction.user_id == current_user.id ? :settler : :settlee
  else
    :owner
  end
end
```

### Step 2 — Derive render_as

```ruby
RENDER_AS = {
  [:expense,    :personal, :owner]       => "personal_expense",
  [:income,     :personal, :owner]       => "personal_income",
  [:transfer,   :personal, :owner]       => "transfer",
  [:expense,    :shared,   :payer]       => "shared_expense_payer",
  [:expense,    :shared,   :participant] => "shared_expense_participant",
  [:settlement, :shared,   :settler]     => "settlement_settler",
  [:settlement, :shared,   :settlee]     => "settlement_settlee",
}.freeze

def render_as(transaction, role)
  RENDER_AS[[transaction.transaction_type.to_sym,
             transaction.visibility_type.to_sym,
             role]]
end
```

### Step 3 — Build summary block

```ruby
def build_summary(transaction, current_user, role)
  case role
  when :payer
    viewer_split = transaction.transaction_splits.find { |s| s.user_id == current_user.id }
    lent = transaction.amount_cents - viewer_split.owed_amount_cents
    { label: "you lent", amount_cents: lent, paid_by_label: "You" }

  when :participant
    my_split = transaction.transaction_splits.find { |s| s.user_id == current_user.id }
    { label: "you owe", amount_cents: my_split.owed_amount_cents,
      paid_by_label: transaction.user.full_name }

  when :settler
    { label: "you paid back", amount_cents: transaction.amount_cents, paid_by_label: "You" }

  when :settlee
    { label: "you received", amount_cents: transaction.amount_cents,
      paid_by_label: transaction.user.full_name }

  when :owner
    label = transaction.income? ? "you received" :
            transaction.transfer? ? "you transferred" : "you paid"
    { label: label, amount_cents: transaction.amount_cents, paid_by_label: "You" }
  end
end
```

### Step 4 — Build paid_by

```ruby
def build_paid_by(transaction, current_user)
  payer = transaction.user
  {
    id:     payer.id,
    name:   payer.full_name,
    is_you: payer.id == current_user.id
  }
end
```

### Step 5 — Build counterpart (settlement only)

```ruby
def build_counterpart(transaction, current_user, role)
  return nil unless transaction.settlement?

  other = role == :settler ? transaction.settles_user : transaction.user
  { id: other.id, name: other.full_name }
end
```

### Step 6 — Build splits (shared expense only)

```ruby
def build_splits(transaction, current_user)
  return nil unless transaction.shared? && transaction.expense?

  splits = transaction.transaction_splits.includes(:user, :category)

  # Viewer's split first, then alphabetical
  viewer, others = splits.partition { |s| s.user_id == current_user.id }
  (viewer + others.sort_by { |s| s.user.full_name }).map do |s|
    {
      user: {
        id:     s.user.id,
        name:   s.user.full_name,
        is_you: s.user_id == current_user.id
      },
      owed_amount_cents: s.owed_amount_cents,
      allocation_value:  s.allocation_value&.to_f,
      category: s.category ? { id: s.category.id, name: s.category.name } : nil
    }
  end
end
```

### Step 7 — Assemble final hash

```ruby
def serialize_transaction(transaction, current_user)
  role = viewer_role(transaction, current_user)

  {
    id:          transaction.id,
    type:        transaction.transaction_type,
    visibility:  transaction.visibility_type,
    title:       transaction.title,
    note:        transaction.note,
    date:        transaction.transaction_date.iso8601,
    currency:    { code: transaction.currency.code, symbol: transaction.currency.symbol },
    amount_cents: transaction.amount_cents,
    render_as:   render_as(transaction, role),
    viewer_role: role,
    summary:     build_summary(transaction, current_user, role),
    paid_by:     build_paid_by(transaction, current_user),
    account:     { id: transaction.account.id, name: transaction.account.name },
    transfer_to_account: transaction.transfer_account&.then { |a| { id: a.id, name: a.name } },
    category:    transaction.category&.then { |c| { id: c.id, name: c.name } },
    counterpart: build_counterpart(transaction, current_user, role),
    split_method: (transaction.shared? && transaction.expense?) ?
                    transaction.transaction_splits.first&.split_method : nil,
    splits:      build_splits(transaction, current_user)
  }
end
```

---

## Frontend: List View Rendering

Every list row has the same structure regardless of transaction type:

```
┌─────────────────────────────────────────────────────┐
│ {title}                     {summary.label}          │
│ {summary.paid_by_label}     {summary.amount_cents}   │
│ paid Rs {amount_cents}                               │
└─────────────────────────────────────────────────────┘
```

**Pseudo-code:**

```
row.left_title     = transaction.title
row.right_label    = transaction.summary.label          // "you lent", "you owe", etc.
row.right_amount   = format(transaction.summary.amount_cents, transaction.currency)
row.secondary_line = "{summary.paid_by_label} paid {format(amount_cents, currency)}"
                     // e.g. "You paid Rs 3,000" or "Ahmed paid Rs 3,000"

onTap → openDetailView(transaction.render_as, transaction.id)
```

**Color hint:**
- `you lent` / `you received` → green (money in your favor)
- `you owe` / `you paid` / `you paid back` / `you transferred` → red/neutral

---

## Frontend: Detail View Rendering

Use `render_as` to pick the correct screen component, then render using
the fields below. The frontend never needs to check `type` + `visibility`
together.

### shared_expense_payer / shared_expense_participant

```
Header:
  {title}
  {format(amount_cents)}  •  {date}
  {note}

Sub-header:
  if paid_by.is_you  → "You paid {format(amount_cents)}"
  else               → "{paid_by.name} paid {format(amount_cents)}"

Split method badge:  {split_method}   // "equal" | "50% / 30% / 20%" | etc.

Splits list (splits array, viewer's entry first):
  for each split:
    left:   split.user.is_you ? "You owe" : "{split.user.name} owes"
    right:  format(split.owed_amount_cents)
    sub:    if split_method == "percentage" → "{split.allocation_value}%"
            if split_method == "shares"     → "{split.allocation_value} shares"
            else                            → ""
    highlight row where split.user.is_you == true
```

### personal_expense / personal_income

```
Header:
  {title}
  {format(amount_cents)}  •  {date}
  {note}

Details:
  Account:   {account.name}
  Category:  {category.name}
```

### transfer

```
Header:
  {title}
  {format(amount_cents)}  •  {date}
  {note}

Details:
  From: {account.name}
  To:   {transfer_to_account.name}
```

### settlement_settler / settlement_settlee

```
Header:
  {title}
  {format(amount_cents)}  •  {date}

Sub-header:
  settlement_settler → "You paid {counterpart.name} back"
  settlement_settlee → "{paid_by.name} paid you back"

Details:
  Account:  {account.name}
  With:     {counterpart.name}
```

---

## Concrete Examples

### 1. Shared expense — payer view
Ahmed pays Rs 3,000, split equally 3 ways.

```json
{
  "id": 1,
  "type": "expense",
  "visibility": "shared",
  "title": "Dinner at Café",
  "note": "Split equally",
  "date": "2026-06-10T19:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 3000,
  "render_as": "shared_expense_payer",
  "viewer_role": "payer",
  "summary": {
    "label": "you lent",
    "amount_cents": 2000,
    "paid_by_label": "You"
  },
  "paid_by": { "id": 1, "name": "Ahmed", "is_you": true },
  "account": { "id": 1, "name": "Cash" },
  "transfer_to_account": null,
  "category": { "id": 3, "name": "Food" },
  "counterpart": null,
  "split_method": "equal",
  "splits": [
    {
      "user": { "id": 1, "name": "Ahmed", "is_you": true },
      "owed_amount_cents": 1000,
      "allocation_value": null,
      "category": { "id": 3, "name": "Food" }
    },
    {
      "user": { "id": 2, "name": "Ali", "is_you": false },
      "owed_amount_cents": 1000,
      "allocation_value": null,
      "category": null
    },
    {
      "user": { "id": 3, "name": "Sara", "is_you": false },
      "owed_amount_cents": 1000,
      "allocation_value": null,
      "category": null
    }
  ]
}
```

**List renders:**
```
Dinner at Café     you lent  Rs 2,000
You paid Rs 3,000
```

**Detail renders:**
```
Dinner at Café  •  Rs 3,000  •  10 Jun 2026
"Split equally"

You paid Rs 3,000          [equal]

You owe    Rs 1,000  ← highlighted
Ali owes   Rs 1,000
Sara owes  Rs 1,000
```

---

### 2. Shared expense — participant view
Same transaction, Ali is viewing.

```json
{
  "id": 1,
  "type": "expense",
  "visibility": "shared",
  "title": "Dinner at Café",
  "note": "Split equally",
  "date": "2026-06-10T19:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 3000,
  "render_as": "shared_expense_participant",
  "viewer_role": "participant",
  "summary": {
    "label": "you owe",
    "amount_cents": 1000,
    "paid_by_label": "Ahmed"
  },
  "paid_by": { "id": 1, "name": "Ahmed", "is_you": false },
  "account": { "id": 1, "name": "Cash" },
  "transfer_to_account": null,
  "category": { "id": 3, "name": "Food" },
  "counterpart": null,
  "split_method": "equal",
  "splits": [
    {
      "user": { "id": 2, "name": "Ali", "is_you": true },
      "owed_amount_cents": 1000,
      "allocation_value": null,
      "category": null
    },
    {
      "user": { "id": 1, "name": "Ahmed", "is_you": false },
      "owed_amount_cents": 1000,
      "allocation_value": null,
      "category": { "id": 3, "name": "Food" }
    },
    {
      "user": { "id": 3, "name": "Sara", "is_you": false },
      "owed_amount_cents": 1000,
      "allocation_value": null,
      "category": null
    }
  ]
}
```

**List renders:**
```
Dinner at Café       you owe    Rs 1,000
Ahmed paid Rs 3,000
```

**Detail renders:**
```
Dinner at Café  •  Rs 3,000  •  10 Jun 2026
"Split equally"

Ahmed paid Rs 3,000        [equal]

You owe     Rs 1,000  ← highlighted (first, viewer's split)
Ahmed owes  Rs 1,000
Sara owes   Rs 1,000
```

---

### 3. Shared expense — percentage split (payer view)
Ahmed pays Rs 10,000 split 50% / 30% / 20%.

```json
{
  "id": 6,
  "type": "expense",
  "visibility": "shared",
  "title": "Hotel booking",
  "note": null,
  "date": "2026-06-08T12:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 10000,
  "render_as": "shared_expense_payer",
  "viewer_role": "payer",
  "summary": {
    "label": "you lent",
    "amount_cents": 5000,
    "paid_by_label": "You"
  },
  "paid_by": { "id": 1, "name": "Ahmed", "is_you": true },
  "account": { "id": 1, "name": "Cash" },
  "transfer_to_account": null,
  "category": { "id": 8, "name": "Travel" },
  "counterpart": null,
  "split_method": "percentage",
  "splits": [
    {
      "user": { "id": 1, "name": "Ahmed", "is_you": true },
      "owed_amount_cents": 5000,
      "allocation_value": 50.0,
      "category": { "id": 8, "name": "Travel" }
    },
    {
      "user": { "id": 2, "name": "Ali", "is_you": false },
      "owed_amount_cents": 3000,
      "allocation_value": 30.0,
      "category": null
    },
    {
      "user": { "id": 3, "name": "Sara", "is_you": false },
      "owed_amount_cents": 2000,
      "allocation_value": 20.0,
      "category": null
    }
  ]
}
```

**Detail split list renders:**
```
You owe    Rs 5,000    50%   ← highlighted
Ali owes   Rs 3,000    30%
Sara owes  Rs 2,000    20%
```

---

### 4. Personal expense

```json
{
  "id": 2,
  "type": "expense",
  "visibility": "personal",
  "title": "Grocery run",
  "note": null,
  "date": "2026-06-10T10:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 5000,
  "render_as": "personal_expense",
  "viewer_role": "owner",
  "summary": {
    "label": "you paid",
    "amount_cents": 5000,
    "paid_by_label": "You"
  },
  "paid_by": { "id": 1, "name": "Ahmed", "is_you": true },
  "account": { "id": 1, "name": "Cash" },
  "transfer_to_account": null,
  "category": { "id": 5, "name": "Groceries" },
  "counterpart": null,
  "split_method": null,
  "splits": null
}
```

---

### 5. Personal income

```json
{
  "id": 3,
  "type": "income",
  "visibility": "personal",
  "title": "Salary",
  "note": null,
  "date": "2026-06-01T00:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 100000,
  "render_as": "personal_income",
  "viewer_role": "owner",
  "summary": {
    "label": "you received",
    "amount_cents": 100000,
    "paid_by_label": "You"
  },
  "paid_by": { "id": 1, "name": "Ahmed", "is_you": true },
  "account": { "id": 2, "name": "Bank Account" },
  "transfer_to_account": null,
  "category": { "id": 7, "name": "Salary" },
  "counterpart": null,
  "split_method": null,
  "splits": null
}
```

---

### 6. Transfer

```json
{
  "id": 4,
  "type": "transfer",
  "visibility": "personal",
  "title": "Cash to bank",
  "note": null,
  "date": "2026-06-10T12:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 10000,
  "render_as": "transfer",
  "viewer_role": "owner",
  "summary": {
    "label": "you transferred",
    "amount_cents": 10000,
    "paid_by_label": "You"
  },
  "paid_by": { "id": 1, "name": "Ahmed", "is_you": true },
  "account": { "id": 1, "name": "Cash" },
  "transfer_to_account": { "id": 2, "name": "Bank Account" },
  "category": null,
  "counterpart": null,
  "split_method": null,
  "splits": null
}
```

---

### 7. Settlement — settler view
Ali (current_user) pays Ahmed back Rs 1,000.

```json
{
  "id": 5,
  "type": "settlement",
  "visibility": "shared",
  "title": "Settlement",
  "note": null,
  "date": "2026-06-11T09:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 1000,
  "render_as": "settlement_settler",
  "viewer_role": "settler",
  "summary": {
    "label": "you paid back",
    "amount_cents": 1000,
    "paid_by_label": "You"
  },
  "paid_by": { "id": 2, "name": "Ali", "is_you": true },
  "account": { "id": 3, "name": "Ali's Wallet" },
  "transfer_to_account": null,
  "category": null,
  "counterpart": { "id": 1, "name": "Ahmed" },
  "split_method": null,
  "splits": null
}
```

**List renders:**
```
Settlement         you paid back  Rs 1,000
You paid Rs 1,000
```

**Detail renders:**
```
Settlement  •  Rs 1,000  •  11 Jun 2026

You paid Ahmed back

Account:  Ali's Wallet
With:     Ahmed
```

---

### 8. Settlement — settlee view
Ahmed (current_user) sees Ali's payment.

```json
{
  "id": 5,
  "type": "settlement",
  "visibility": "shared",
  "title": "Settlement",
  "note": null,
  "date": "2026-06-11T09:00:00Z",
  "currency": { "code": "PKR", "symbol": "Rs" },
  "amount_cents": 1000,
  "render_as": "settlement_settlee",
  "viewer_role": "settlee",
  "summary": {
    "label": "you received",
    "amount_cents": 1000,
    "paid_by_label": "Ali"
  },
  "paid_by": { "id": 2, "name": "Ali", "is_you": false },
  "account": { "id": 3, "name": "Ali's Wallet" },
  "transfer_to_account": null,
  "category": null,
  "counterpart": { "id": 2, "name": "Ali" },
  "split_method": null,
  "splits": null
}
```

**List renders:**
```
Settlement          you received  Rs 1,000
Ali paid Rs 1,000
```

**Detail renders:**
```
Settlement  •  Rs 1,000  •  11 Jun 2026

Ali paid you back

Account:  Ali's Wallet
With:     Ali
```

---

## Settlement Perspective Logic (backend)

The `Transaction` model has both `user_id` (the settler who initiated and
paid) and `settles_user_id` (the person being paid back / the creditor).

```ruby
# transaction.user      = Ali   (settler — debtor who paid)
# transaction.settles_user = Ahmed (settlee — creditor who received)

if current_user.id == transaction.user_id
  role = :settler      # "you paid back"
elsif current_user.id == transaction.settles_user_id
  role = :settlee      # "you received"
end
```

Both users can see this transaction in their transaction lists.
The serializer is called with the same transaction record but a different
`current_user`, producing the two different responses above.

---

## Splits Array Ordering

Always order splits so the viewer's entry comes first:

```ruby
viewer, others = splits.partition { |s| s.user_id == current_user.id }
ordered = viewer + others.sort_by { |s| s.user.full_name }
```

This means the frontend can always highlight `splits[0]` as the viewer's
row without scanning.

---

## Null Field Reference

| Field                | When null                                        |
|----------------------|--------------------------------------------------|
| `note`               | No note was added                                |
| `transfer_to_account`| Not a transfer                                   |
| `category`           | Transfer, or shared expense with no payer cat    |
| `counterpart`        | Not a settlement                                 |
| `split_method`       | Not a shared expense                             |
| `splits`             | Not a shared expense                             |
| `splits[].category`  | Participant hasn't assigned their personal cat   |
| `splits[].allocation_value` | split_method is equal or exact          |
