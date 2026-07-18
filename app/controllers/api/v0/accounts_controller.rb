module Api::V0
  class AccountsController < ApiController
    resource_description do
      short "Accounts management"
      description "Manage financial accounts for the current user. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/accounts", "List all accounts for the current user"
    description <<~DESC
      Returns all accounts belonging to the authenticated user, ordered by creation date descending.

      **TypeScript Types**

      ```typescript
      // Input: none (authenticated via JWT header)

      // Output
      type Response = {
        success: boolean;
        accounts: Account[];
      };

      type Account = {
        id: number;
        name: string;
        current_balance_cents: number;
        initial_balance_cents: number;
        is_archived: boolean;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :accounts, Array, desc: "List of accounts" do
        param :id, Integer, desc: "Account ID"
        param :name, String, desc: "Account name"
        param :current_balance_cents, Integer, desc: "Current balance in cents"
        param :initial_balance_cents, Integer, desc: "Initial balance in cents"
        param :is_archived, :bool, desc: "Whether the account is archived"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def index
      Api::V0::Accounts::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :GET, "/v0/accounts/:id", "Get a specific account"
    description <<~DESC
      Returns a single account by ID. Only accessible if the account belongs to the current user.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };

      // Output
      type Response = {
        success: boolean;
        account: Account;
      };

      type Account = {
        id: number;
        name: string;
        current_balance_cents: number;
        initial_balance_cents: number;
        is_archived: boolean;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Account ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Account not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :account, Hash, desc: "Account data" do
        param :id, Integer, desc: "Account ID"
        param :name, String, desc: "Account name"
        param :current_balance_cents, Integer, desc: "Current balance in cents"
        param :initial_balance_cents, Integer, desc: "Initial balance in cents"
        param :is_archived, :bool, desc: "Whether the account is archived"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def show
      Api::V0::Accounts::Show.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :POST, "/v0/accounts", "Create a new account"
    description <<~DESC
      Creates a new account for the authenticated user.

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        name: string;
        current_balance_cents?: number; // default: 0
        initial_balance_cents?: number; // default: 0
      };

      // Output
      type Response = {
        success: boolean;
        account: Account;
      };

      type Account = {
        id: number;
        name: string;
        current_balance_cents: number;
        initial_balance_cents: number;
        is_archived: boolean;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :name, String, required: true, description: "Account name"
    param :current_balance_cents, Integer, required: false, description: "Current balance in cents (default: 0)"
    param :initial_balance_cents, Integer, required: false, description: "Initial balance in cents (default: 0)"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 422, desc: "Validation errors"
    returns code: 201, desc: "Account created" do
      param :success, :bool, desc: "Operation status"
      param :account, Hash, desc: "Created account data" do
        param :id, Integer, desc: "Account ID"
        param :name, String, desc: "Account name"
        param :current_balance_cents, Integer, desc: "Current balance in cents"
        param :initial_balance_cents, Integer, desc: "Initial balance in cents"
        param :is_archived, :bool, desc: "Whether the account is archived"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def create
      Api::V0::Accounts::Create.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :PATCH, "/v0/accounts/:id", "Update an existing account"
    description <<~DESC
      Updates an existing account. Only fields provided will be updated.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        name?: string;
        current_balance_cents?: number;
        initial_balance_cents?: number;
      };

      // Output
      type Response = {
        success: boolean;
        account: Account;
      };

      type Account = {
        id: number;
        name: string;
        current_balance_cents: number;
        initial_balance_cents: number;
        is_archived: boolean;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Account ID"
    param :name, String, required: false, description: "Account name"
    param :current_balance_cents, Integer, required: false, description: "Current balance in cents"
    param :initial_balance_cents, Integer, required: false, description: "Initial balance in cents"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Account not found"
    error code: 422, desc: "Validation errors"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :account, Hash, desc: "Updated account data" do
        param :id, Integer, desc: "Account ID"
        param :name, String, desc: "Account name"
        param :current_balance_cents, Integer, desc: "Current balance in cents"
        param :initial_balance_cents, Integer, desc: "Initial balance in cents"
        param :is_archived, :bool, desc: "Whether the account is archived"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def update
      Api::V0::Accounts::Update.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/accounts/:id", "Delete an account"
    description <<~DESC
      Permanently deletes an account. This action cannot be undone.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };

      // Output
      type Response = {
        success: boolean;
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Account ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Account not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
    end
    def destroy
      Api::V0::Accounts::Destroy.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
