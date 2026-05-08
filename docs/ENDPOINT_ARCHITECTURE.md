# Endpoint Architecture Guide

This document describes the canonical way to build a complete API endpoint in this codebase. Every new endpoint must follow this structure end-to-end.

---

## Directory Layout

```
app/
  controllers/
    api/
      v{n}/
        {resources}_controller.rb        # thin controller

  operations/
    api/
      v{n}/
        {resource}/
          index.rb                       # one file per action
          show.rb
          create.rb
          update.rb
          destroy.rb

  serializers/
    api/
      v{n}/
        {resource}_serializer.rb         # Blueprinter serializer

  services/
    {domain}/
      {verb}_{noun}.rb                   # extracted business logic (only when reusable)

  policies/
    {resource}_policy.rb                 # Pundit policy

spec/
  requests/
    api/
      v{n}/
        {resources}/
          index_spec.rb                  # one spec file per action
          create_spec.rb
          ...
  support/
    api/
      schemas/
        {resource}/
          index_response.json
          create_response.json
          error_response.json            # shared across all endpoints
```

---

## 1. Controller

Controllers are **thin**. Their only job is to:
1. Pass the raw request params and context (`current_user`) to an operation.
2. Match the result and render the appropriate HTTP response.

No param filtering, no business logic, no ActiveRecord calls.

```ruby
# app/controllers/api/v1/posts_controller.rb
module Api::V1
  class PostsController < ApiController
    before_action :require_current_user!

    def index
      Api::V1::Posts::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def show
      Api::V1::Posts::Show.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def create
      Api::V1::Posts::Create.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def update
      Api::V1::Posts::Update.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def destroy
      Api::V1::Posts::Destroy.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
```

**Response helpers available on `ApiController`:**

| Helper | Status |
|---|---|
| `render json: data, status: :ok` | 200 |
| `render json: data, status: :created` | 201 |
| `unauthorized_response` | 401 |
| `forbidden_response` | 403 |
| `not_found_response` | 404 |
| `unprocessable_entity(errors)` | 422 |

---

## 2. Operation

One operation = one controller action. Each operation:

- Includes `Api::V1::ApplicationOperation` (provides `validate_contract`, `Success`, `Failure`, `yield`).
- Has a nested `Contract` class for param validation.
- Has a single **public** `call` method that sequences all steps.
- Has all helper methods as **private**.
- Uses `attr_reader` in the private section to hold state instead of passing it between methods.
- Returns `Failure(:symbol)` for authorization/not-found errors and `Failure(errors: hash)` for validation errors.
- Returns `Success(data_hash)` on the happy path — the hash is rendered directly as JSON.

```ruby
# app/operations/api/v1/posts/create.rb
module Api::V1::Posts
  class Create
    include Api::V1::ApplicationOperation

    class Contract < Api::V1::ApplicationContract
      params do
        required(:title).filled(:string)
        required(:body).filled(:string)
        optional(:published).maybe(:bool)
      end
    end

    def call(params, current_user:)
      @current_user = current_user
      validated    = yield validate_contract(post_params(params))
      @attributes  = validated

      yield authorize
      yield persist

      Success(
        success: true,
        post: Api::V1::PostSerializer.render_as_hash(post)
      )
    end

    private

    attr_reader :current_user, :attributes, :post

    def post_params(params)
      params.fetch(:post, params.fetch("post", {}))
    end

    def authorize
      PostPolicy.new(current_user, Post.new).create? ? Success() : Failure(:forbidden)
    end

    def persist
      @post = Post.new(attributes.merge(author: current_user))
      post.save ? Success(post) : Failure(errors: post.errors.to_hash)
    end
  end
end
```

### Step flow rules

- Each step method returns `Success(...)` or `Failure(...)`.
- `yield` on a step short-circuits the `call` method if that step returns `Failure`.
- `return Failure(...)` (without yield) is used for guard clauses that should not raise (e.g., record not found).
- Keep steps small — if a step grows or could be reused by another operation, extract it to a service.

### When authorization is needed

Add an `authorize` step **after** contract validation but **before** any writes. Call the Pundit policy directly — do not use `authorize` from Pundit's controller helpers inside an operation.

```ruby
def authorize
  PostPolicy.new(current_user, record).update? ? Success() : Failure(:forbidden)
end
```

---

## 3. Contract

Contracts inherit from `Api::V1::ApplicationContract` and use `dry-validation` syntax. Define them as a nested class inside the operation that owns them.

```ruby
class Contract < Api::V1::ApplicationContract
  params do
    required(:title).filled(:string)
    optional(:status).maybe(Types::String.enum("draft", "published"))
  end

  rule(:title) do
    key.failure("is too short") if value.length < 3
  end
end
```

`validate_contract` is provided by `ApplicationOperation`. It returns `Success(params_hash)` or `Failure(errors: hash)`.

---

## 4. Serializer

Serializers use [Blueprinter](https://github.com/procore-oss/blueprinter). Every endpoint returns the **same object shape** using the default view — no named views. This keeps the frontend TypeScript types simple: one type per resource, consistent across index, show, create, and update responses.

```ruby
# app/serializers/api/v1/post_serializer.rb
module Api::V1
  class PostSerializer < Blueprinter::Base
    identifier :id

    fields :title, :body, :published, :created_at, :updated_at
    association :author, blueprint: UserSerializer
  end
end
```

Render inside an operation — no `view:` argument needed:

```ruby
# single record
Api::V1::PostSerializer.render_as_hash(post)

# collection
Api::V1::PostSerializer.render_as_hash(posts)
```

The response shape for `POST /posts`, `GET /posts/:id`, and `PATCH /posts/:id` is identical. The frontend defines one `Post` type and reuses it everywhere.

---

## 5. Policy

Policies live in `app/policies/` and follow the Pundit convention.

```ruby
# app/policies/post_policy.rb
class PostPolicy
  attr_reader :current_user, :record

  def initialize(current_user, record)
    @current_user = current_user
    @record       = record
  end

  def index?   = current_user.present?
  def show?    = current_user.present?
  def create?  = current_user.present?
  def update?  = owner? || current_user.admin?
  def destroy? = owner? || current_user.admin?

  private

  def owner?
    record.author_id == current_user.id
  end
end
```

---

## 6. Service

Extract logic to a service only when:
- The step involves non-trivial business logic **and**
- It is (or is likely to be) reused across more than one operation.

Services inherit `ApplicationService` which mixes in `Dry::Monads[:result]` and exposes `.call`.

```ruby
# app/services/posts/publish.rb
module Posts
  class Publish < ApplicationService
    def call(post)
      return Failure(:already_published) if post.published?

      post.update!(published: true, published_at: Time.current)
      Success(post)
    rescue ActiveRecord::RecordInvalid => e
      Failure(errors: e.record.errors.to_hash)
    end
  end
end
```

Use inside an operation:

```ruby
def publish
  yield Posts::Publish.call(post)
end
```

---

## 7. Request Spec

Every endpoint has a corresponding request spec. Full rules are in [docs/RSPEC_REQUEST_SPECS_LLM_RULES.md](RSPEC_REQUEST_SPECS_LLM_RULES.md).

Summary:
- One `describe` block per action.
- All params as `let` variables; one `before` block fires the request.
- Every response body assertion uses `match_json_schema`.
- Two top-level comment sections: `# SUCCESS PATHS` and `# FAILURE PATHS`.
- Cover every scenario in the coverage table (auth, permissions, validation, not found, etc.).

```ruby
# spec/requests/api/v1/posts/create_spec.rb
# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Api::V1::Posts", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  def auth_token_for(u)
    result = Jwt::Issuer.call(u)
    "Bearer #{result.data[:access_token]}"
  end

  describe "POST /api/v1/posts" do
    let(:endpoint)        { "/api/v1/posts" }
    let(:request_headers) { headers }
    let(:title)           { "My Post" }
    let(:body)            { "Post content here." }

    let(:request_params) do
      { post: { title: title, body: body } }
    end

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with valid params" do
      let(:request_headers) { headers.merge("Authorization" => auth_token_for(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("posts/create_response")
      end

      it "persists the post" do
        expect(Post.find_by(title: title)).to be_present
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when title is blank" do
      let(:request_headers) { headers.merge("Authorization" => auth_token_for(user)) }
      let(:title)           { "" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
```

JSON schema for the success response (`spec/support/api/schemas/posts/create_response.json`):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["success", "post"],
  "properties": {
    "success": { "type": "boolean", "enum": [true] },
    "post": { "$ref": "#/definitions/post" }
  },
  "definitions": {
    "post": {
      "type": "object",
      "required": ["id", "title", "body", "created_at"],
      "properties": {
        "id":         { "type": "integer" },
        "title":      { "type": "string" },
        "body":       { "type": "string" },
        "created_at": { "type": "string", "format": "date-time" }
      }
    }
  }
}
```

---

## Quick Reference — Failure Symbols and HTTP Status

| Failure returned by operation | Controller maps to |
|---|---|
| `Failure(:not_found)` | `not_found_response` → 404 |
| `Failure(:forbidden)` | `forbidden_response` → 403 |
| `Failure(:unauthorized)` | `unauthorized_response` → 401 |
| `Failure(errors: hash)` | `unprocessable_entity(errors)` → 422 |

---

## Checklist for a New Endpoint

- [ ] Route added to `config/routes.rb`
- [ ] Controller action calls operation, maps all failure symbols
- [ ] Operation: contract, `call`, private steps, `attr_reader`
- [ ] Authorization step present (if endpoint is protected)
- [ ] Serializer exposes all fields needed (default view only — no named views)
- [ ] Business logic in service if reusable; inline if not
- [ ] JSON schema files created for success and (shared) error responses
- [ ] Request spec covers all rows of the coverage table that apply
