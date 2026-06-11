# RupeeRally — DB Schema Reference

## Design Principles

- Every money movement = one `transactions` record
- Shared expenses split via `transaction_splits`
- Debt balances stored pre-calculated in `debts` (not computed on-the-fly)
- No business logic in callbacks — use service objects
- For reporting, use `transaction_splits.owed_amount`, not `transactions.amount`

---

## Enums

```ruby
# Transaction
enum transaction_type: { expense: 0, income: 1, transfer: 2, settlement: 3 }
enum visibility_type:  { personal: 0, shared: 1 }

# TransactionSplit
enum split_method: { equal: 0, percentage: 1, shares: 2, exact: 3 }

# Group
enum kind: { custom: 0, friends: 1 }
```

---

## Tables

### users
| Column             | Type      | Null  | Notes                                  |
|--------------------|-----------|-------|----------------------------------------|
| id                 | bigint    | false | PK                                     |
| full_name          | string    | false |                                        |
| email              | string    | false | unique                                 |
| password_digest    | string    | false | has_secure_password                    |
| default_account_id | bigint    | true  | FK → accounts; used for settlements    |
| created_at         | datetime  | false |                                        |
| updated_at         | datetime  | false |                                        |

```ruby
validates :full_name, presence: true
validates :email, presence: true, uniqueness: true

has_many :accounts
belongs_to :default_account, class_name: 'Account', foreign_key: :default_account_id, optional: true
has_many :transactions
has_many :transaction_splits
has_many :groups_users
has_many :groups, through: :groups_users
has_many :created_groups, class_name: 'Group', foreign_key: :created_by_id
has_one  :friends_group, -> { friends }, class_name: 'Group', foreign_key: :created_by_id
has_many :debts_from, class_name: 'Debt', foreign_key: :from_user_id
has_many :debts_to,   class_name: 'Debt', foreign_key: :to_user_id
```

> `default_account_id` is used by the settlement service to credit the recipient's account when a settlement is recorded. Must be set on any user expected to receive settlements.

---

### currencies
| Column     | Type     | Null  | Notes        |
|------------|----------|-------|--------------|
| id         | bigint   | false | PK           |
| code       | string   | false | unique, e.g. PKR |
| name       | string   | false |              |
| symbol     | string   | false | e.g. Rs      |
| created_at | datetime | false |              |
| updated_at | datetime | false |              |

```ruby
validates :code,   presence: true, uniqueness: true
validates :name,   presence: true
validates :symbol, presence: true

has_many :accounts
has_many :transactions
```

---

### accounts
| Column               | Type     | Null  | Notes                     |
|----------------------|----------|-------|---------------------------|
| id                   | bigint   | false | PK                        |
| user_id              | bigint   | false | FK → users                |
| currency_id          | bigint   | false | FK → currencies           |
| name                 | string   | false |                           |
| account_type         | string   | false | cash / bank / wallet      |
| initial_balance_cents| integer  | false | default: 0, stored in cents|
| current_balance_cents| integer  | false | default: 0, stored in cents|
| is_archived          | boolean  | false | default: false            |
| created_at           | datetime | false |                           |
| updated_at           | datetime | false |                           |

```ruby
validates :name,                 presence: true
validates :account_type,         presence: true
validates :initial_balance_cents, numericality: { only_integer: true }
validates :current_balance_cents, numericality: { only_integer: true }

belongs_to :user
belongs_to :currency
has_many   :transactions
```

---

### categories
| Column        | Type     | Null  | Notes                |
|---------------|----------|-------|----------------------|
| id            | bigint   | false | PK                   |
| user_id       | bigint   | false | FK → users           |
| name          | string   | false |                      |
| category_type | string   | false | expense / income     |
| created_at    | datetime | false |                      |
| updated_at    | datetime | false |                      |

```ruby
validates :name,          presence: true
validates :category_type, presence: true

belongs_to :user
has_many   :transactions
```

---

### groups
| Column        | Type     | Null  | Notes            |
|---------------|----------|-------|------------------|
| id            | bigint   | false | PK               |
| created_by_id | bigint   | false | FK → users       |
| name          | string   | false |                  |
| description   | text     | true  |                  |
| kind          | integer  | false | custom / friends |
| created_at    | datetime | false |                  |
| updated_at    | datetime | false |                  |

```ruby
enum kind: { custom: 0, friends: 1 }

validates :name, presence: true
validates :kind, presence: true

belongs_to :created_by, class_name: 'User'
has_many   :groups_users
has_many   :users, through: :groups_users
has_many   :transactions
```

---

### groups_users
| Column     | Type     | Null  | Notes        |
|------------|----------|-------|--------------|
| id         | bigint   | false | PK           |
| group_id   | bigint   | false | FK → groups  |
| user_id    | bigint   | false | FK → users   |
| created_at | datetime | false |              |
| updated_at | datetime | false |              |

```ruby
add_index :groups_users, [:group_id, :user_id], unique: true

validates :group_id, uniqueness: { scope: :user_id }

belongs_to :group
belongs_to :user
```

---

### transactions
| Column              | Type          | Null  | Notes                        |
|---------------------|---------------|-------|------------------------------|
| id                  | bigint        | false | PK                           |
| user_id             | bigint        | false | creator / payer              |
| account_id          | bigint        | false | money source                 |
| category_id         | bigint        | true  | null for transfers           |
| currency_id         | bigint        | false | FK                           |
| group_id            | bigint        | true  | FK, shared expenses only     |
| transaction_type    | integer       | false | enum                         |
| visibility_type     | integer       | false | enum                         |
| amount_cents        | integer       | false | positive, stored in cents    |
| title               | string        | false |                              |
| note                | text          | true  |                              |
| transaction_date    | datetime      | false |                              |
| transfer_account_id | bigint        | true  | destination for transfers    |
| created_at          | datetime      | false |                              |
| updated_at          | datetime      | false |                              |

```ruby
validates :amount_cents,     presence: true, numericality: { only_integer: true, greater_than: 0 }
validates :title,            presence: true
validates :transaction_type, presence: true
validates :visibility_type,  presence: true

validate :group_required_for_shared
validate :transfer_account_required
validate :transfer_accounts_must_differ

# group_required_for_shared
errors.add(:group_id, 'is required') if shared? && group_id.blank?

# transfer_account_required
errors.add(:transfer_account_id, 'is required') if transfer? && transfer_account_id.blank?

# transfer_accounts_must_differ
errors.add(:transfer_account_id, 'must be different') if transfer_account_id == account_id

belongs_to :user
belongs_to :account
belongs_to :category,         optional: true
belongs_to :currency
belongs_to :group,            optional: true
belongs_to :transfer_account, class_name: 'Account', optional: true
has_many   :transaction_splits, dependent: :destroy
```

Indexes:
```ruby
add_index :transactions, :user_id
add_index :transactions, :account_id
add_index :transactions, :group_id
add_index :transactions, :transaction_date
add_index :transactions, :transaction_type
```

---

### transaction_splits
| Column           | Type           | Null  | Notes                                         |
|------------------|----------------|-------|-----------------------------------------------|
| id               | bigint         | false | PK                                            |
| transaction_id   | bigint         | false | FK → transactions                             |
| user_id          | bigint         | false | FK → users                                    |
| category_id      | bigint         | true  | FK → categories; participant's personal category |
| split_method     | integer        | false | enum                                          |
| allocation_value | decimal(15,4)  | true  | percentage % or shares count                  |
| owed_amount_cents| integer        | false | final calculated amount in cents              |
| created_at       | datetime       | false |                                               |
| updated_at       | datetime       | false |                                               |

```ruby
validates :owed_amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
validates :split_method, presence: true

validate :allocation_value_required

# allocation_value_required
if percentage? || shares?
  errors.add(:allocation_value, 'is required') if allocation_value.blank?
end

belongs_to :transaction
belongs_to :user
belongs_to :category, optional: true
```

> `category_id` is the participant's **personal** category for this shared expense. It is separate from `transactions.category_id` (the payer's category). Non-payers leave it nil at creation and assign it later. This makes "my spending by category" queries symmetric — always hit `transaction_splits` for shared expenses regardless of whether you are the payer.

Indexes:
```ruby
add_index :transaction_splits, :transaction_id
add_index :transaction_splits, :user_id
add_index :transaction_splits, :category_id
```

---

### friendships
| Column         | Type     | Null  | Notes                              |
|----------------|----------|-------|------------------------------------|
| id             | bigint   | false | PK                                 |
| user_a_id      | bigint   | false | FK → users (smaller ID)            |
| user_b_id      | bigint   | false | FK → users (larger ID)             |
| requested_by_id| bigint   | false | FK → users                         |
| status         | integer  | false | pending / accepted / blocked       |
| created_at     | datetime | false |                                    |
| updated_at     | datetime | false |                                    |

```ruby
enum :status, { pending: 0, accepted: 1, blocked: 2 }

validates :status, presence: true
validate  :users_must_differ
validate  :user_a_must_have_smaller_id  # enforces canonical ordering

belongs_to :user_a,       class_name: 'User'
belongs_to :user_b,       class_name: 'User'
belongs_to :requested_by, class_name: 'User'

scope :accepted, -> { where(status: :accepted) }
scope :pending,  -> { where(status: :pending) }

# Returns the other participant given one side
def other_user(current_user) = current_user.id == user_a_id ? user_b : user_a
def involves?(user) = user_a_id == user.id || user_b_id == user.id
```

Indexes:
```ruby
add_index :friendships, [:user_a_id, :user_b_id], unique: true
```

> Symmetric constraint: always store `min(user_a_id, user_b_id)` in `user_a_id` and `max` in `user_b_id`. The unique index on `[user_a_id, user_b_id]` guarantees one row per pair.

---

### debts
| Column       | Type          | Null  | Notes              |
|--------------|---------------|-------|--------------------|
| id           | bigint        | false | PK                 |
| from_user_id | bigint        | false | FK → users (owes)  |
| to_user_id   | bigint        | false | FK → users (owed)  |
| amount_cents | integer       | false | current net debt in cents |
| created_at   | datetime      | false |                    |
| updated_at   | datetime      | false |                    |

```ruby
add_index :debts, [:from_user_id, :to_user_id], unique: true

validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
validate  :users_must_differ

# users_must_differ
errors.add(:to_user_id, 'must be different') if from_user_id == to_user_id

belongs_to :from_user, class_name: 'User'
belongs_to :to_user,   class_name: 'User'
```
