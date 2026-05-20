# RupeeRally — Claude Code Reference

## Project Overview

Rails API for personal + shared expense tracking. Auth via JWT. Money stored in cents throughout.

## Stack

- Ruby on Rails (API mode) — `app/controllers/api/v1/`
- `dry-monads`, `dry-validation` — operations/contracts
- Blueprinter — serializers
- Pundit — authorization
- RSpec — request specs with JSON schema validation

---

## Architecture

### Request Flow

```
Controller (thin) → Operation → [Policy, Service, Serializer] → JSON response
```

### Directory Layout

```
app/
  controllers/api/v1/      # thin — call operation, match result, render
  operations/api/v1/{resource}/{action}.rb  # one file per action
  serializers/api/v1/      # Blueprinter, default view only
  services/{domain}/       # reusable business logic (dry-monads)
  policies/                # Pundit
spec/requests/api/v1/{resource}/{action}_spec.rb
spec/support/api/schemas/{resource}/{action}_response.json
```

---

## Operation Rules

- Includes `Api::V1::ApplicationOperation`
- Nested `Contract < Api::V1::ApplicationContract` (dry-validation)
- **Contract runs automatically** — never call `validate_contract` manually
- **Symbol keys only** — never `params[:x] || params["x"]`
- `@params` via `attr_reader`; use `params.slice(...)` to build model attributes
- `call` is public, all helpers private
- Steps return `Success(...)` or `Failure(...)`; `yield` short-circuits on failure
- `authorize?` step before any writes — call Pundit policy directly (not controller helpers)
- Return `Success(serialized_hash)` — rendered as JSON

```ruby
def call(params, current_user:)
  @params, @current_user = params, current_user
  yield authorize?
  yield persist
  Success(post: Api::V1::PostSerializer.render_as_hash(@post))
end
```

**Failure → HTTP mapping:**

| Failure | Status |
|---|---|
| `Failure(:not_found)` | 404 |
| `Failure(:forbidden)` | 403 |
| `Failure(:unauthorized)` | 401 |
| `Failure(errors: hash)` | 422 |

---

## Service Rules

- Inherit `ApplicationService`, implement `#call`
- Return `Success(value)` or `Failure(reason)` only — never raise raw
- One public method; no HTTP knowledge; pass individual args, not `params`
- Extract to service only when logic is reused across operations

---

## Serializer Rules

- Blueprinter, default view only (no named views)
- One type per resource, same shape across all actions
- Render: `ResourceSerializer.render_as_hash(record_or_collection)`

---

## Money / Business Logic

- All amounts in **cents** (e.g., `amount_cents`, `owed_amount_cents`)
- `transactions.amount_cents` = full amount paid
- `transaction_splits.owed_amount_cents` = each user's share → use for reports
- `debts` = pre-calculated net balance (one row per user pair, always net before saving)

### Transaction Types

| type | visibility | splits? | updates debts? |
|---|---|---|---|
| expense | personal | no | no |
| expense | shared | yes | yes |
| income | personal | no | no |
| transfer | personal | no | no |
| settlement | personal | no | yes (reduces) |

### Split Methods

- **equal** — divide evenly, no `allocation_value`
- **percentage** — `allocation_value` = %, must sum to 100
- **shares** — `allocation_value` = share count
- **exact** — `owed_amount` entered directly

### Debt Algorithm (shared expense)

1. For each split where `user != payer`: payer is owed `owed_amount` by that user
2. Net against existing debt row for the pair
3. Net = 0 → delete row; direction flips → swap `from/to_user_id`

### Shared Expense Update

Never overwrite debts directly: reverse old debts → delete old splits → create new splits → apply new debts.

### Key Services

| Service | Responsibility |
|---|---|
| `Transactions::CreateExpense` | transaction + splits + debts |
| `Transactions::UpdateExpense` | reverse old debts, delete splits, reapply |
| `Transactions::CreateSettlement` | settlement transaction + reduce debt |
| `Debts::UpdateBalances` | net and persist debt for a user pair |

---

## Request Spec Rules

- One spec file per action: `spec/requests/api/v1/{resource}/{action}_spec.rb`
- All params as `let` variables; one `before` block fires the request
- **Every response body assertion must use `match_json_schema`**
- Two sections per endpoint: `# SUCCESS PATHS` and `# FAILURE PATHS`
- Factory data only (`create(:factory)`) — never `Model.create!`
- No helper methods — use `let` and `before` only

```ruby
def auth_token_for(user)
  result = Jwt::Issuer.call(user)
  "Bearer #{result.data[:access_token]}"
end
```

### Required Coverage

| Scenario | GET index | GET show | POST | PATCH | DELETE |
|---|---|---|---|---|---|
| Authenticated, valid | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unauthenticated | ✅ | ✅ | ✅ | ✅ | ✅ |
| Forbidden | ✅ | ✅ | ✅ | ✅ | ✅ |
| Not found | — | ✅ | — | ✅ | ✅ |
| Missing/invalid param | — | — | ✅ | ✅ | — |

---

## DB Key Constraints

- `transactions`: `group_id` required if `shared`; `transfer_account_id` required if `transfer`
- `transaction_splits`: `allocation_value` required for `percentage` / `shares`
- `debts`: unique on `[from_user_id, to_user_id]`; `amount_cents > 0`; `from != to`
- No callbacks for business logic — use service objects
