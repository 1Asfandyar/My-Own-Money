module Api::V0
  class DashboardController < ApiController
    resource_description do
      short "Dashboard"
      description "Dashboard data for the authenticated user."
      api_version "v0"
    end

    api :GET, "/v0/dashboard", "Get dashboard data"
    description <<~DESC
      Returns current-month income/expense summary, overall debt totals,
      and pre-serialized lists of accounts, categories, and accepted friendships.

      **TypeScript Types**

      ```typescript
      type Response = {
        success: boolean;
        summary: Summary;
        accounts: Account[];
        categories: Category[];
        friendships: Friendship[];
      };

      type Summary = {
        total_income: number;             // current month
        total_expense: number;            // current month
        total_owed_to_you_cents: number;  // overall
        total_you_owe_cents: number;      // overall
      };

      type Account = {
        id: number;
        name: string;
        current_balance_cents: number;
        initial_balance_cents: number;
        is_archived: boolean;
        currency_symbol: string | null;
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };

      type Category = {
        id: number;
        name: string;
        icon: string | null;
        color: string | null;
        balance_cents: number;
        category_type: "expense" | "income";
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };

      type Friendship = {
        id: number;
        status: "pending" | "accepted" | "blocked";
        requested_by_id: number;
        friend: User;
        balance: Balance;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };

      type User = {
        id: number;
        full_name: string;
        mobile_number: string;
        email: string;
        role: string;
        onboarding_completed: boolean;
        currency_id: number;
        currency_symbol: string | null;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };

      type Balance = {
        type: "owes_you" | "you_owe" | "settled_up";
        amount_cents: number;
      };
      ```
    DESC
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :summary, Hash, desc: "Dashboard summary" do
        param :total_income, Integer, desc: "Current month total income in cents"
        param :total_expense, Integer, desc: "Current month total expense in cents"
        param :total_owed_to_you_cents, Integer, desc: "Overall total owed to the current user, in cents"
        param :total_you_owe_cents, Integer, desc: "Overall total the current user owes, in cents"
      end
      param :accounts, Array, desc: "List of current user's accounts" do
        param :id, Integer, desc: "Account ID"
        param :name, String, desc: "Account name"
        param :current_balance_cents, Integer, desc: "Current balance in cents"
        param :initial_balance_cents, Integer, desc: "Initial balance in cents"
        param :is_archived, :bool, desc: "Whether the account is archived"
        param :currency_symbol, String, desc: "Currency symbol (e.g. $)"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
      param :categories, Array, desc: "List of current user's categories" do
        param :id, Integer, desc: "Category ID"
        param :name, String, desc: "Category name"
        param :icon, String, desc: "Optional icon"
        param :color, String, desc: "Optional color"
        param :balance_cents, Integer, desc: "Current category balance in cents"
        param :category_type, String, desc: "Category type: expense or income"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
      param :friendships, Array, desc: "Accepted friendships for the current user" do
        param :id, Integer, desc: "Friendship ID"
        param :status, String, desc: "Friendship status"
        param :requested_by_id, Integer, desc: "ID of the user who sent the friend request"
        param :friend, Hash, desc: "The other user in the friendship" do
          param :id, Integer, desc: "User ID"
          param :full_name, String, desc: "Full name"
          param :mobile_number, String, desc: "Mobile number"
          param :email, String, desc: "Email address"
          param :role, String, desc: "User role"
          param :onboarding_completed, :bool, desc: "Whether onboarding is completed"
          param :currency_id, Integer, desc: "Preferred currency ID"
          param :currency_symbol, String, desc: "Preferred currency symbol"
          param :created_at, String, desc: "ISO 8601 creation timestamp"
          param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        end
        param :balance, Hash, desc: "Net balance between current user and friend" do
          param :type, String, desc: "owes_you | you_owe | settled_up"
          param :amount_cents, Integer, desc: "Net amount in cents"
        end
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def show
      Api::V0::Dashboard::Show.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
