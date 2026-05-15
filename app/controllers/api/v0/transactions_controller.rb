module Api::V0
  class TransactionsController < ApiController
    resource_description do
      short "Transactions management"
      description "Manage financial transactions for the current user. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/transactions", "List all transactions for the current user"
    description <<~DESC
      Returns all transactions belonging to the authenticated user, ordered by transaction date descending.
      Supports optional filtering by account, category, date range, and keyword search.

      **TypeScript Types**

      ```typescript
      // Input (all optional query params)
      type Query = {
        account_id?: number;
        category_id?: number;
        date_from?: string; // ISO 8601
        date_to?: string;   // ISO 8601
        search?: string;    // matches title or note (case-insensitive)
      };

      // Output
      type Response = {
        success: boolean;
        transactions: Transaction[];
      };

      type Transaction = {
        id: number;
        title: string;
        amount_cents: number;
        transaction_type: "income" | "expense" | "transfer";
        visibility_type: string;
        transaction_date: string; // ISO 8601
        note: string | null;
        account_id: number | null;
        transfer_account_id: number | null;
        category_id: number | null;
        currency_id: number;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :account_id, Integer, required: false, desc: "Filter by account ID"
    param :category_id, Integer, required: false, desc: "Filter by category ID"
    param :date_from, String, required: false, desc: "Filter transactions on or after this ISO 8601 datetime"
    param :date_to, String, required: false, desc: "Filter transactions on or before this ISO 8601 datetime"
    param :search, String, required: false, desc: "Search by title or note (case-insensitive)"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :transactions, Array, desc: "List of transactions" do
        param :id, Integer, desc: "Transaction ID"
        param :title, String, desc: "Transaction title"
        param :amount_cents, Integer, desc: "Amount in cents"
        param :transaction_type, String, desc: "One of: income, expense, transfer"
        param :visibility_type, String, desc: "Visibility type"
        param :transaction_date, String, desc: "ISO 8601 transaction date"
        param :note, String, desc: "Optional note"
        param :account_id, Integer, desc: "Account ID (nil for transfers)"
        param :transfer_account_id, Integer, desc: "Destination account ID for transfers"
        param :category_id, Integer, desc: "Category ID (nil for transfers)"
        param :currency_id, Integer, desc: "Currency ID"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def index
      Api::V0::Transactions::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :GET, "/v0/transactions/:id", "Get a specific transaction"
    description <<~DESC
      Returns a single transaction by ID. Only accessible if the transaction belongs to the current user.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };

      // Output
      type Response = {
        success: boolean;
        transaction: Transaction;
      };

      type Transaction = {
        id: number;
        title: string;
        amount_cents: number;
        transaction_type: "income" | "expense" | "transfer";
        visibility_type: string;
        transaction_date: string; // ISO 8601
        note: string | null;
        account_id: number | null;
        transfer_account_id: number | null;
        category_id: number | null;
        currency_id: number;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :id, Integer, required: true, desc: "Transaction ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Transaction not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :transaction, Hash, desc: "Transaction data" do
        param :id, Integer, desc: "Transaction ID"
        param :title, String, desc: "Transaction title"
        param :amount_cents, Integer, desc: "Amount in cents"
        param :transaction_type, String, desc: "One of: income, expense, transfer"
        param :visibility_type, String, desc: "Visibility type"
        param :transaction_date, String, desc: "ISO 8601 transaction date"
        param :note, String, desc: "Optional note"
        param :account_id, Integer, desc: "Account ID (nil for transfers)"
        param :transfer_account_id, Integer, desc: "Destination account ID for transfers"
        param :category_id, Integer, desc: "Category ID (nil for transfers)"
        param :currency_id, Integer, desc: "Currency ID"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def show
      Api::V0::Transactions::Show.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :POST, "/v0/transactions", "Create a new transaction"
    description <<~DESC
      Creates a new transaction for the authenticated user.

      For **income** or **expense** transactions: provide `account_id` and `category_id`.
      For **transfer** transactions: provide `from_account_id` and `to_account_id` instead.
      For **shared expense** transactions: also provide `paid_by`, `split_method`, and one of:
        - `shared_by` (array of user IDs) when `split_method` is `"equal"` — amounts are divided evenly.
        - `user_shares` (array of `{user_id, share_amount_cents}`) when `split_method` is `"exact"` — amounts are explicit.
        - `account_id` and `category_id` must belong to the `paid_by` user.
        - `transaction_date` defaults to today if omitted.

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        title: string;
        transaction_type: "income" | "expense" | "transfer";
        amount_cents: number;             // must be > 0
        transaction_date?: string;        // ISO 8601; defaults to today
        note?: string;
        currency_id?: number;

        // for income / expense
        account_id?: number;
        category_id?: number;

        // for transfer
        from_account_id?: number;
        to_account_id?: number;

        // for shared expense — equal split
        paid_by?: number;                 // user ID of who paid; required for any shared expense
        shared_by?: number[];             // user IDs sharing the expense (required for split_method "equal")
        // for shared expense — non-equal splits
        user_shares?: Array<{             // required for split_method "exact" | "percentage" | "shares"
          user_id: number;
          share: number;                  // meaning depends on split_method:
                                          //   exact:      amount in cents (must sum to amount_cents)
                                          //   percentage: percentage value (must sum to 100)
                                          //   shares:     relative share count
        }>;
        split_method?: "equal" | "exact" | "percentage" | "shares"; // required when shared_by or user_shares present
      };

      // Output
      type Response = {
        success: boolean;
        transaction: Transaction;
      };
      ```
    DESC
    param :title, String, required: true, desc: "Transaction title"
    param :transaction_type, String, required: true, desc: "One of: income, expense, transfer"
    param :amount_cents, Integer, required: true, desc: "Amount in cents (must be > 0)"
    param :transaction_date, String, required: false, desc: "ISO 8601 transaction date (defaults to today)"
    param :note, String, required: false, desc: "Optional note"
    param :currency_id, Integer, required: false, desc: "Currency ID (defaults to account currency)"
    param :account_id, Integer, required: false, desc: "Account ID (required for income/expense; must belong to paid_by for shared)"
    param :category_id, Integer, required: false, desc: "Category ID (required for income/expense; must belong to paid_by for shared)"
    param :from_account_id, Integer, required: false, desc: "Source account ID (required for transfer)"
    param :to_account_id, Integer, required: false, desc: "Destination account ID (required for transfer)"
    param :paid_by, Integer, required: false, desc: "User ID of who paid (required for shared expense)"
    param :shared_by, Array, required: false, desc: "Array of user IDs sharing the expense (required for split_method equal)"
    param :user_shares, Array, required: false, desc: "Array of {user_id, share} objects (required for split_method exact, percentage, or shares)"
    param :split_method, String, required: false, desc: "Split method: equal, exact, percentage, shares (required when shared_by or user_shares present)"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Account, category, or currency not found"
    error code: 422, desc: "Validation errors"
    returns code: 201, desc: "Transaction created" do
      param :success, :bool, desc: "Operation status"
      param :transaction, Hash, desc: "Created transaction data" do
        param :id, Integer, desc: "Transaction ID"
        param :title, String, desc: "Transaction title"
        param :amount_cents, Integer, desc: "Amount in cents"
        param :transaction_type, String, desc: "One of: income, expense, transfer"
        param :visibility_type, String, desc: "Visibility type"
        param :transaction_date, String, desc: "ISO 8601 transaction date"
        param :note, String, desc: "Optional note"
        param :account_id, Integer, desc: "Account ID (nil for transfers)"
        param :transfer_account_id, Integer, desc: "Destination account ID for transfers"
        param :category_id, Integer, desc: "Category ID (nil for transfers)"
        param :currency_id, Integer, desc: "Currency ID"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def create
      Api::V0::Transactions::Create.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :PATCH, "/v0/transactions/:id", "Update an existing transaction"
    description <<~DESC
      Updates an existing transaction. Only fields provided will be updated.

      For transfers, updating `from_account_id` or `to_account_id` changes the linked accounts.
      Changing `transaction_type` between personal and transfer types is supported.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        title?: string;
        transaction_type?: "income" | "expense" | "transfer";
        amount_cents?: number;       // must be > 0
        transaction_date?: string;   // ISO 8601
        note?: string | null;
        currency_id?: number;
        account_id?: number;
        category_id?: number;
        from_account_id?: number;
        to_account_id?: number;
      };

      // Output
      type Response = {
        success: boolean;
        transaction: Transaction;
      };
      ```
    DESC
    param :id, Integer, required: true, desc: "Transaction ID"
    param :title, String, required: false, desc: "Transaction title"
    param :transaction_type, String, required: false, desc: "One of: income, expense, transfer"
    param :amount_cents, Integer, required: false, desc: "Amount in cents (must be > 0)"
    param :transaction_date, String, required: false, desc: "ISO 8601 transaction date"
    param :note, String, required: false, desc: "Optional note (pass null to clear)"
    param :currency_id, Integer, required: false, desc: "Currency ID"
    param :account_id, Integer, required: false, desc: "Account ID (for income/expense)"
    param :category_id, Integer, required: false, desc: "Category ID (for income/expense)"
    param :from_account_id, Integer, required: false, desc: "Source account ID (for transfer)"
    param :to_account_id, Integer, required: false, desc: "Destination account ID (for transfer)"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 404, desc: "Transaction, account, category, or currency not found"
    error code: 422, desc: "Validation errors"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :transaction, Hash, desc: "Updated transaction data" do
        param :id, Integer, desc: "Transaction ID"
        param :title, String, desc: "Transaction title"
        param :amount_cents, Integer, desc: "Amount in cents"
        param :transaction_type, String, desc: "One of: income, expense, transfer"
        param :visibility_type, String, desc: "Visibility type"
        param :transaction_date, String, desc: "ISO 8601 transaction date"
        param :note, String, desc: "Optional note"
        param :account_id, Integer, desc: "Account ID (nil for transfers)"
        param :transfer_account_id, Integer, desc: "Destination account ID for transfers"
        param :category_id, Integer, desc: "Category ID (nil for transfers)"
        param :currency_id, Integer, desc: "Currency ID"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def update
      Api::V0::Transactions::Update.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/transactions/:id", "Delete a transaction"
    description <<~DESC
      Permanently deletes a transaction. For transfer transactions, both the debit and credit
      entries are removed and account balances are reversed. This action cannot be undone.

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
    param :id, Integer, required: true, desc: "Transaction ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 404, desc: "Transaction not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
    end
    def destroy
      Api::V0::Transactions::Destroy.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
