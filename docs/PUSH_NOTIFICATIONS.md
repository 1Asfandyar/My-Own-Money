# Push Notifications

FCM push notifications via **rpush** + **Solid Queue**.

## Stack

- `rpush` gem — manages the FCM notification queue in Postgres
- `Notifications::Send` service — creates rpush records per device token
- `Notifications::SendJob` — async wrapper (Solid Queue, `default` queue)
- `device_tokens` table — stores per-user FCM tokens

---

## Setup

```bash
bundle install
bundle exec rpush init   # creates rpush_apps / rpush_notifications tables
bundle exec rails db:migrate
```

Add to `.env`:

```
FCM_PROJECT_ID=<Project number from Firebase Console → Project Settings → General>
FCM_JSON_KEY=<contents of the service account JSON key — see below>
```

**Getting `FCM_PROJECT_ID`:**
1. Firebase Console → Project Settings → **General** tab
2. Copy the **Project number** (numeric, e.g. `123456789012`) — not the Project ID string

**Getting `FCM_JSON_KEY`:**
1. Firebase Console → Project Settings → **Service Accounts** tab
2. Click **Generate new private key** → download the `.json` file
3. The service account role is granted automatically
4. Convert to a single line and paste as `FCM_JSON_KEY`:
```bash
cat your-downloaded-key.json | tr -d '\n'
```

> If key creation is blocked by an org policy, create the Firebase project under a personal Gmail account — org policies don't apply to personal accounts.

The initializer (`config/initializers/rpush.rb`) auto-creates the `rupeerally` rpush app record on boot using these env vars.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v0/device_tokens` | Register FCM token |
| DELETE | `/api/v0/device_tokens/:id` | Unregister token |

**Register body:**
```json
{ "token": "<fcm_token>", "platform": "android" }
```

- `platform`: `android` or `ios`
- Upserts — safe to call on every app launch (handles token refresh)

---

## Sending a Notification

```ruby
# Async (preferred)
Notifications::SendJob.perform_later(
  user_id: user.id,
  title:   "New expense",
  body:    "Asfandyar added $20 to Lahore Trip",
  data:    { transaction_id: 42 }
)

# Inline (e.g. from tests or rake tasks)
Notifications::Send.call(user: user, title: "...", body: "...", data: {})
```

`data` is merged onto the FCM payload and available in the React Native notification handler.

---

## Processes

`Procfile.dev` runs three processes:

```
web:  rails server
jobs: bin/jobs start       # Solid Queue — runs SendJob, writes rpush_notifications records
push: bundle exec rpush start -f   # rpush daemon — reads those records and calls FCM
```

Both are required. They handle different stages of the same pipeline:

```
perform_later(...)
      ↓
  Solid Queue (bin/jobs)     ← picks up SendJob, calls Notifications::Send
      ↓
  rpush_notifications row written to DB
      ↓
  rpush daemon (rpush start) ← reads row, POSTs to FCM HTTP v1, marks delivered
      ↓
  Device receives notification
```

In production, run `bundle exec rpush start` as a persistent process (systemd, Heroku worker dyno, etc.).

---

## File Map

```
app/
  models/device_token.rb
  policies/device_token_policy.rb
  serializers/api/v0/device_token_serializer.rb
  controllers/api/v0/device_tokens_controller.rb
  operations/api/v0/device_tokens/register.rb
  operations/api/v0/device_tokens/unregister.rb
  services/notifications/send.rb
  jobs/notifications/send_job.rb
config/initializers/rpush.rb
db/migrate/20260521000001_create_device_tokens.rb
```
