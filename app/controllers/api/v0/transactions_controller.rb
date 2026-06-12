module Api::V0
  class TransactionsController < ApiController
    resource_description do
      short "Transactions management"
      description "Manage financial transactions for the current user. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/transactions", "List transactions visible to the current user"
    description <<~DESC
      Returns transactions visible to the authenticated user, ordered by transaction date descending.
      A transaction is visible when the user is the creator, a split participant, or the settlee of a settlement.
      Supports filtering by account, category, friend, group, transaction type, visibility, date range, and keyword.
      Results are paginated — defaults to page 1 with 25 records per page.

      **TypeScript Types**

      ```typescript
      // Input (all optional query params)
      type Query = {
        account_id?:       number;
        category_id?:      number;
        friend_id?:        number;  // only transactions where both current user and this user participated
        group_id?:         number;  // only shared expenses belonging to this group
        transaction_type?: "income" | "expense" | "transfer" | "settlement";
        visibility_type?:  "personal" | "shared";
        date_from?:        string;  // ISO 8601 lower bound (inclusive)
        date_to?:          string;  // ISO 8601 upper bound (inclusive)
        search?:           string;  // case-insensitive match against title or note
        page?:             number;  // default: 1
        per_page?:         number;  // default: 25
      };

      // Output
      type Response = {
        success: boolean;
        transactions: Transaction[];
      };

      type Transaction = {
        id:                  number;
        type:                "expense" | "income" | "transfer" | "settlement";
        visibility:          "personal" | "shared";
        title:               string;
        note:                string | null;
        date:                string;          // ISO 8601
        currency:            { code: string; symbol: string };
        amount_cents:        number;
        render_as:           "personal_expense" | "personal_income" | "transfer" | "shared_expense_payer" | "shared_expense_participant" | "settlement_settler" | "settlement_settlee";
        viewer_role:         "owner" | "payer" | "participant" | "settler" | "settlee";
        summary:             Summary;
        paid_by:             UserWithIsYou;
        account:             { id: number; name: string };
        transfer_to_account: { id: number; name: string } | null;
        category:            { id: number; name: string } | null;
        counterpart:         { id: number; name: string } | null;
        split_method:        string | null;
        splits:              Split[] | null;
      };

      type Summary = {
        label:         string;  // e.g. "you lent", "you owe", "you paid"
        amount_cents:  number;
        paid_by_label: string;  // "You" or payer's name
      };

      type UserWithIsYou = {
        id:     number;
        name:   string;
        is_you: boolean;
      };

      type Split = {
        user:              UserWithIsYou;
        owed_amount_cents: number;
        allocation_value:  number | null;
        category:          { id: number; name: string } | null;
      };
      ```
    DESC
    param :account_id,       Integer, required: false, desc: "Filter by account ID"
    param :category_id,      Integer, required: false, desc: "Filter by category ID (matches payer's category or user's split category)"
    param :friend_id,        Integer, required: false, desc: "Only transactions where both the current user and this user participated"
    param :group_id,         Integer, required: false, desc: "Only shared expenses belonging to this group"
    param :transaction_type, String,  required: false, desc: "Filter by type: income, expense, transfer, or settlement"
    param :visibility_type,  String,  required: false, desc: "Filter by visibility: personal or shared"
    param :date_from,        String,  required: false, desc: "ISO 8601 lower bound on transaction_date (inclusive)"
    param :date_to,          String,  required: false, desc: "ISO 8601 upper bound on transaction_date (inclusive)"
    param :search,           String,  required: false, desc: "Case-insensitive search against title or note"
    param :page,             Integer, required: false, desc: "Page number (default: 1)"
    param :per_page,         Integer, required: false, desc: "Records per page (default: 25)"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 422, desc: "Invalid date format for date_from or date_to"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :transactions, Array, desc: "Paginated list of transactions" do
        param :id,                  Integer, desc: "Transaction ID"
        param :type,                String,  desc: "One of: expense, income, transfer, settlement"
        param :visibility,          String,  desc: "personal or shared"
        param :title,               String,  desc: "Transaction title"
        param :note,                String,  desc: "Optional note (null if absent)"
        param :date,                String,  desc: "ISO 8601 transaction date"
        param :currency,            Hash,    desc: "{ code, symbol } of the transaction currency" do
          param :code,   String, desc: "Currency code (e.g. USD)"
          param :symbol, String, desc: "Currency symbol (e.g. $)"
        end
        param :amount_cents,        Integer, desc: "Full amount paid by the payer, in cents"
        param :render_as,           String,  desc: "UI hint: personal_expense, personal_income, transfer, shared_expense_payer, shared_expense_participant, settlement_settler, settlement_settlee"
        param :viewer_role,         String,  desc: "Viewer's role: owner, payer, participant, settler, settlee"
        param :summary,             Hash,    desc: "Viewer-relative summary for display" do
          param :label,         String,  desc: "Human-readable label (e.g. 'you lent', 'you owe', 'you paid')"
          param :amount_cents,  Integer, desc: "Viewer-relevant amount in cents"
          param :paid_by_label, String,  desc: "'You' or the payer's name"
        end
        param :paid_by,             Hash,    desc: "The user who paid" do
          param :id,     Integer, desc: "User ID"
          param :name,   String,  desc: "Display name"
          param :is_you, :bool,   desc: "True when the viewer is the payer"
        end
        param :account,             Hash,    desc: "Source account { id, name }" do
          param :id,   Integer, desc: "Account ID"
          param :name, String,  desc: "Account name"
        end
        param :transfer_to_account, Hash,    desc: "Destination account { id, name } for transfers, or null"
        param :category,            Hash,    desc: "Category { id, name }, or null"
        param :counterpart,         Hash,    desc: "The other party { id, name } for settlements, or null"
        param :split_method,        String,  desc: "equal, exact, percentage, or shares (null for non-shared expenses)"
        param :splits,              Array,   desc: "Split details for shared expenses, null otherwise" do
          param :user,              Hash,    desc: "Participant" do
            param :id,     Integer, desc: "User ID"
            param :name,   String,  desc: "Display name"
            param :is_you, :bool,   desc: "True when this split belongs to the viewer"
          end
          param :owed_amount_cents, Integer, desc: "Amount owed by this participant, in cents"
          param :allocation_value,  Float,   desc: "Raw allocation value (null for equal splits)"
          param :category,          Hash,    desc: "Participant's category { id, name }, or null"
        end
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
        id:                  number;
        type:                "expense" | "income" | "transfer" | "settlement";
        visibility:          "personal" | "shared";
        title:               string;
        note:                string | null;
        date:                string;          // ISO 8601
        currency:            { code: string; symbol: string };
        amount_cents:        number;
        render_as:           "personal_expense" | "personal_income" | "transfer" | "shared_expense_payer" | "shared_expense_participant" | "settlement_settler" | "settlement_settlee";
        viewer_role:         "owner" | "payer" | "participant" | "settler" | "settlee";
        summary:             Summary;
        paid_by:             UserWithIsYou;
        account:             { id: number; name: string };
        transfer_to_account: { id: number; name: string } | null;
        category:            { id: number; name: string } | null;
        counterpart:         { id: number; name: string } | null;
        split_method:        string | null;
        splits:              Split[] | null;
      };

      type Summary = {
        label:         string;
        amount_cents:  number;
        paid_by_label: string;
      };

      type UserWithIsYou = {
        id:     number;
        name:   string;
        is_you: boolean;
      };

      type Split = {
        user:              UserWithIsYou;
        owed_amount_cents: number;
        allocation_value:  number | null;
        category:          { id: number; name: string } | null;
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
        param :id,                  Integer, desc: "Transaction ID"
        param :type,                String,  desc: "One of: expense, income, transfer, settlement"
        param :visibility,          String,  desc: "personal or shared"
        param :title,               String,  desc: "Transaction title"
        param :note,                String,  desc: "Optional note (null if absent)"
        param :date,                String,  desc: "ISO 8601 transaction date"
        param :currency,            Hash,    desc: "{ code, symbol } of the transaction currency" do
          param :code,   String, desc: "Currency code (e.g. USD)"
          param :symbol, String, desc: "Currency symbol (e.g. $)"
        end
        param :amount_cents,        Integer, desc: "Full amount paid by the payer, in cents"
        param :render_as,           String,  desc: "UI hint: personal_expense, personal_income, transfer, shared_expense_payer, shared_expense_participant, settlement_settler, settlement_settlee"
        param :viewer_role,         String,  desc: "Viewer's role: owner, payer, participant, settler, settlee"
        param :summary,             Hash,    desc: "Viewer-relative summary for display" do
          param :label,         String,  desc: "Human-readable label (e.g. 'you lent', 'you owe', 'you paid')"
          param :amount_cents,  Integer, desc: "Viewer-relevant amount in cents"
          param :paid_by_label, String,  desc: "'You' or the payer's name"
        end
        param :paid_by,             Hash,    desc: "The user who paid" do
          param :id,     Integer, desc: "User ID"
          param :name,   String,  desc: "Display name"
          param :is_you, :bool,   desc: "True when the viewer is the payer"
        end
        param :account,             Hash,    desc: "Source account { id, name }" do
          param :id,   Integer, desc: "Account ID"
          param :name, String,  desc: "Account name"
        end
        param :transfer_to_account, Hash,    desc: "Destination account { id, name } for transfers, or null"
        param :category,            Hash,    desc: "Category { id, name }, or null"
        param :counterpart,         Hash,    desc: "The other party { id, name } for settlements, or null"
        param :split_method,        String,  desc: "equal, exact, percentage, or shares (null for non-shared expenses)"
        param :splits,              Array,   desc: "Split details for shared expenses, null otherwise" do
          param :user,              Hash,    desc: "Participant" do
            param :id,     Integer, desc: "User ID"
            param :name,   String,  desc: "Display name"
            param :is_you, :bool,   desc: "True when this split belongs to the viewer"
          end
          param :owed_amount_cents, Integer, desc: "Amount owed by this participant, in cents"
          param :allocation_value,  Float,   desc: "Raw allocation value (null for equal splits)"
          param :category,          Hash,    desc: "Participant's category { id, name }, or null"
        end
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
      Creates a new transaction for the authenticated user. The current user is always the payer / creator.

      For **income** or **expense** transactions: provide `account_id` and `category_id` (both required).
      For **transfer** transactions: provide `from_account_id` and `to_account_id` instead.
      For **shared expense** transactions: provide `account_id`, `category_id`, `split_method`, and one of:
        - `shared_by` (array of user IDs) when `split_method` is `"equal"` — amounts are divided evenly.
        - `user_shares` (array of `{user_id, share}`) for `"exact"`, `"percentage"`, or `"shares"` splits.
        - `account_id` and `category_id` must belong to the current user.
        - The current user's category balance is updated by their own share amount.
        - `transaction_date` defaults to today if omitted.
      For **settlement** transactions: provide `account_id` and `settles_user_id` (the user being paid back).
        - Records that the current user paid `settles_user_id` the given `amount_cents`.
        - Reduces the debt between the current user and `settles_user_id` by `amount_cents`.
        - `category_id` is not required for settlements.
        - Settlement transactions cannot be updated — delete and re-create if correction is needed.

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        title: string;
        transaction_type: "income" | "expense" | "transfer" | "settlement";
        amount_cents: number;             // must be > 0
        transaction_date?: string;        // ISO 8601; defaults to today
        note?: string;
        currency_id?: number;

        // for income / expense (both required)
        account_id?: number;
        category_id?: number;

        // for transfer
        from_account_id?: number;
        to_account_id?: number;

        // for shared expense — equal split
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

        // for settlement (account_id required; category_id not required)
        settles_user_id?: number;         // required for settlement — the user being paid back

        // for group shared expense (current user must be a member of the group)
        group_id?: number;
      };

      // Output
      type Response = {
        success: boolean;
        transaction: Transaction;
      };
      ```
    DESC
    param :title, String, required: true, desc: "Transaction title"
    param :transaction_type, String, required: true, desc: "One of: income, expense, transfer, settlement"
    param :amount_cents, Integer, required: true, desc: "Amount in cents (must be > 0)"
    param :transaction_date, String, required: false, desc: "ISO 8601 transaction date (defaults to today)"
    param :note, String, required: false, desc: "Optional note"
    param :currency_id, Integer, required: false, desc: "Currency ID (defaults to account currency)"
    param :account_id, Integer, required: false, desc: "Account ID — required for income, expense (personal & shared), and settlement; belongs to current user"
    param :category_id, Integer, required: false, desc: "Category ID — required for income and expense (personal & shared); not required for settlement; belongs to current user"
    param :from_account_id, Integer, required: false, desc: "Source account ID (required for transfer)"
    param :to_account_id, Integer, required: false, desc: "Destination account ID (required for transfer)"
    param :shared_by, Array, required: false, desc: "Array of user IDs sharing the expense (required for split_method equal)"
    param :user_shares, Array, required: false, desc: "Array of {user_id, share} objects (required for split_method exact, percentage, or shares)"
    param :split_method, String, required: false, desc: "Split method: equal, exact, percentage, shares (required when shared_by or user_shares present)"
    param :settles_user_id, Integer, required: false, desc: "User ID of the person being paid back (required for settlement)"
    param :group_id,        Integer, required: false, desc: "Group ID to link a shared expense to — current user must be a member of the group"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — current user is not a member of the specified group"
    error code: 404, desc: "Account, category, currency, group, or settles_user not found"
    error code: 422, desc: "Validation errors"
    returns code: 201, desc: "Transaction created" do
      param :success, :bool, desc: "Operation status"
      param :transaction, Hash, desc: "Created transaction data" do
        param :id, Integer, desc: "Transaction ID"
        param :title, String, desc: "Transaction title"
        param :amount_cents, Integer, desc: "Amount in cents"
        param :transaction_type, String, desc: "One of: income, expense, transfer, settlement"
        param :visibility_type, String, desc: "Visibility type"
        param :transaction_date, String, desc: "ISO 8601 transaction date"
        param :note, String, desc: "Optional note"
        param :account_id, Integer, desc: "Account ID"
        param :transfer_account_id, Integer, desc: "Destination account ID for transfers"
        param :category_id, Integer, desc: "Category ID (nil for transfers/settlements)"
        param :settles_user_id, Integer, desc: "User ID being paid back (nil unless settlement)"
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

      **Settlement transactions** support updating `title`, `amount_cents`, `account_id`,
      `transaction_date`, `note`, and `currency_id`. Changing `transaction_type` or
      `settles_user_id` on a settlement is not supported.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        title?: string;
        transaction_type?: "income" | "expense" | "transfer"; // ignored for settlements
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
    param :transaction_type, String, required: false, desc: "One of: income, expense, transfer (settlement cannot be updated)"
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
        param :account_id, Integer, desc: "Account ID"
        param :transfer_account_id, Integer, desc: "Destination account ID for transfers"
        param :category_id, Integer, desc: "Category ID (nil for transfers)"
        param :settles_user_id, Integer, desc: "User ID being paid back (nil unless settlement)"
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
