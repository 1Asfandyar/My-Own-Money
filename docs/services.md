# Services

Services encapsulate reusable business logic. They live below operations (which handle HTTP concerns) and above models (which handle persistence).

Use a service when logic is shared across multiple operations, jobs, or mailers — or when a controller/operation is getting too heavy.

## Creating a service

Inherit from `ApplicationService` and implement `#call`:

```ruby
# app/services/users/deactivate.rb
class Users::Deactivate < ApplicationService
  def call(user)
    return Failure(:already_inactive) if user.inactive?

    user.update!(active: false)
    Success(user)
  end
end
```

Services return `Success(value)` or `Failure(reason)` from `dry-monads`. Always return one of these — never raise or return a raw value.

## Calling a service

```ruby
# Inline result handling
case Users::Deactivate.call(user)
in Success(user)  then render json: user
in Failure(:already_inactive) then render json: { error: "Already inactive" }, status: :unprocessable_entity
end

# Or assign and check
result = Users::Deactivate.call(user)
result.success? # => true / false
result.value!   # the Success value (raises if Failure)
result.failure  # the Failure reason (nil if Success)
```

## File layout

Group services by domain under `app/services/`:

```
app/services/
  application_service.rb     # base class — do not modify
  users/
    deactivate.rb
    send_welcome_email.rb
  payments/
    charge.rb
```

## Rules

- One public method: `#call`. All other methods are `private`.
- No HTTP knowledge — no `params`, no `render`, no `request`.
- Keep `#call` signatures small. Pass individual arguments, not raw `params` hashes.
- If a service needs multiple collaborators, inject them via the constructor and default in `#call`.
