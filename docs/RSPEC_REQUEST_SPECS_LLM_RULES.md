# RSpec Request Specs — Rules for LLM Code Generation

## Core Mandate

- Each `describe` block tests **one endpoint end-to-end** (full HTTP request → response cycle)
- Cover **every success path** and **every failure path** — no gaps, no redundancy
- **Every** test that checks a response body must use `match_json_schema` — never skip schema validation

---

## File Structure

```ruby
# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Api::V0::Resources", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:owner_user) { create(:user) }

  def auth_token_for(user)
    result = Jwt::Issuer.call(user)
    "Bearer #{result.data[:access_token]}"
  end

  describe "POST /api/v0/resources" do
    # 1. endpoint + all params as let variables at describe scope
    let(:endpoint)        { "/api/v0/resources" }
    let(:request_headers) { headers }
    let(:resource_name)   { "Valid Name" }

    let(:request_params) do
      { resource: { name: resource_name } }
    end

    # 2. ONE before block fires the request
    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with valid params" do
      let(:request_headers) { headers.merge("Authorization" => auth_token_for(owner_user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("resources/create_response")
      end

      it "persists the resource" do
        expect(Resource.find_by(name: resource_name)).to be_present
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 403 and matches error schema" do
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when name is blank" do
      let(:request_headers) { headers.merge("Authorization" => auth_token_for(owner_user)) }
      let(:resource_name)   { "" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
```

---

## Rules

### 1. Params — always `let` variables
- Define each param field as its **own** `let` variable with a valid default value
- Compose `request_params` hash from those variables
- To test a variation: override the individual `let` in a nested `context` — never mutate

### 2. Request — one `before` block per `describe`
- The `before` block calls the HTTP method using the `let` variables
- Tests only make assertions — they never call the HTTP method themselves

### 3. JSON Schema — mandatory for every response
- Every response body assertion must use `match_json_schema("resource/action_response")`
- Schema files live in `spec/support/api/schemas/<resource>/`
- Reuse `$ref` and `definitions` to avoid duplication across schemas
- `error_response.json` is the shared schema for all error responses

### 4. Context organisation
- Two top-level sections per endpoint: `# SUCCESS PATHS` and `# FAILURE PATHS`
- Context name = short scenario description: `"when unauthenticated"`, `"when name is blank"`
- One context per distinct scenario — don't combine unrelated variations
- Don't write a context with only one trivially obvious test; merge it into a parent context instead

### 5. No redundancy
- Don't repeat the same assertion in multiple contexts
- Don't test the same HTTP status code twice for the same scenario
- Don't write a status-only test AND a schema test as separate `it` blocks — combine them in one `it`

### 6. Factory data only
- `create(:factory_name, overrides)` — never `Model.create!`
- Define factory records as `let` variables

### 7. No helper methods in spec files
- Use `let` and `before` — no `def make_request(...)` style helpers

---

## Required Coverage Per HTTP Method

| Scenario | GET index | GET show | POST | PATCH | DELETE |
|---|---|---|---|---|---|
| Authenticated, valid input | ✅ | ✅ | ✅ | ✅ | ✅ |
| Each permitted role | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unauthenticated | ✅ | ✅ | ✅ | ✅ | ✅ |
| Insufficient permissions | ✅ | ✅ | ✅ | ✅ | ✅ |
| Record not found | — | ✅ | — | ✅ | ✅ |
| Missing required param | — | — | ✅ | ✅ | — |
| Invalid param value | — | — | ✅ | ✅ | — |
| Uniqueness violation | — | — | ✅ | ✅ | — |
| Dependency conflict | — | — | — | — | ✅ |
| Protected/system record | — | — | — | ✅ | ✅ |

---

## JSON Schema Template

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["success", "data"],
  "properties": {
    "success": { "type": "boolean", "enum": [true] },
    "data": { "$ref": "#/definitions/resource" }
  },
  "definitions": {
    "resource": {
      "type": "object",
      "required": ["id", "name", "created_at"],
      "properties": {
        "id":         { "type": "integer" },
        "name":       { "type": "string" },
        "created_at": { "type": "string", "format": "date-time" }
      }
    }
  }
}
```

Error schema (`error_response.json`):
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["success", "errors"],
  "properties": {
    "success": { "type": "boolean", "enum": [false] },
    "errors":  { "type": ["object", "array", "string"] }
  }
}
```
