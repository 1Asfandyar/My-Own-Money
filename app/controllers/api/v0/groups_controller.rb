module Api::V0
  class GroupsController < ApiController
    before_action :require_current_user!

    resource_description do
      short "Groups management"
      description "Manage groups and their members. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/groups", "List groups for the current user"
    description <<~DESC
      Returns all groups the authenticated user belongs to.

      **TypeScript Types**

      ```typescript
      // Output
      type Response = {
        success: boolean;
        groups: Group[];
      };

      type Group = {
        id: number;
        name: string;
        description: string | null;
        created_by_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
        members: Member[];
      };

      type Member = {
        id: number;
        full_name: string;
        mobile_number: string;
        email: string;
        role: string;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :groups, Array, desc: "List of groups the user belongs to" do
        param :id, Integer, desc: "Group ID"
        param :name, String, desc: "Group name"
        param :description, String, desc: "Group description"
        param :created_by_id, Integer, desc: "ID of the user who created the group"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :members, Array, desc: "List of group members" do
          param :id, Integer, desc: "Member user ID"
          param :full_name, String, desc: "Member full name"
          param :mobile_number, String, desc: "Member mobile number"
          param :email, String, desc: "Member email address"
          param :role, String, desc: "Member role in the group (e.g. 'creator', 'member')"
          param :created_at, String, desc: "ISO 8601 timestamp when the member was added to the group"
          param :updated_at, String, desc: "ISO 8601 timestamp when the member's role was last updated"
        end
      end
    end
    def index
      Api::V0::Groups::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :GET, "/v0/groups/:id", "Show a group the current user belongs to"
    description <<~DESC
      Returns a single group by ID. The authenticated user must be a member of the group.
      Includes all group transactions visible to the authenticated user (transactions where the
      user is the creator, a split participant, or the settlee of a settlement).

      **TypeScript Types**

      ```typescript
      // Output
      type Response = {
        success: boolean;
        group: Group;
      };

      type Group = {
        id: number;
        name: string;
        description: string | null;
        created_by_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
        members: Member[];
        transactions: Transaction[];
      };

      type Member = {
        id: number;
        full_name: string;
        mobile_number: string;
        email: string;
        role: string;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };

      type Transaction = {
        id: number;
        type: "expense" | "income" | "transfer" | "settlement";
        visibility: "personal" | "shared";
        title: string;
        note: string | null;
        date: string;          // ISO 8601
        currency: { code: string; symbol: string };
        amount_cents: number;
        render_as: "personal_expense" | "personal_income" | "transfer" | "shared_expense_payer" | "shared_expense_participant" | "settlement_settler" | "settlement_settlee";
        viewer_role: "owner" | "payer" | "participant" | "settler" | "settlee";
        summary: Summary;
        paid_by: UserWithIsYou;
        account: { id: number; name: string };
        transfer_to_account: { id: number; name: string } | null;
        category: { id: number; name: string } | null;
        counterpart: { id: number; name: string } | null;
        split_method: string | null;
        splits: Split[] | null;
      };

      type Summary = {
        label: string;
        amount_cents: number;
        paid_by_label: string;
      };

      type UserWithIsYou = {
        id: number;
        name: string;
        is_you: boolean;
      };

      type Split = {
        user: UserWithIsYou;
        owed_amount_cents: number;
        allocation_value: number | null;
        category: { id: number; name: string } | null;
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Group ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 404, desc: "Group not found or user is not a member"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :group, Hash, desc: "Group data with members and transactions" do
        param :id, Integer, desc: "Group ID"
        param :name, String, desc: "Group name"
        param :description, String, desc: "Group description"
        param :created_by_id, Integer, desc: "ID of the user who created the group"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :members, Array, desc: "List of group members" do
          param :id, Integer, desc: "Member user ID"
          param :full_name, String, desc: "Member full name"
          param :mobile_number, String, desc: "Member mobile number"
          param :email, String, desc: "Member email address"
          param :role, String, desc: "Member role in the group (e.g. 'creator', 'member')"
          param :created_at, String, desc: "ISO 8601 timestamp when the member was added to the group"
          param :updated_at, String, desc: "ISO 8601 timestamp when the member's role was last updated"
        end
        param :transactions, Array, desc: "List of group transactions visible to the authenticated user" do
          param :id, Integer, desc: "Transaction ID"
          param :type, String, desc: "One of: expense, income, transfer, settlement"
          param :visibility, String, desc: "personal or shared"
          param :title, String, desc: "Transaction title"
          param :note, String, desc: "Optional note (null if absent)"
          param :date, String, desc: "ISO 8601 transaction date"
          param :currency, Hash, desc: "{ code, symbol } of the transaction currency" do
            param :code, String, desc: "Currency code (e.g. USD)"
            param :symbol, String, desc: "Currency symbol (e.g. $)"
          end
          param :amount_cents, Integer, desc: "Full amount paid by the payer, in cents"
          param :render_as, String, desc: "UI hint: personal_expense, personal_income, transfer, shared_expense_payer, shared_expense_participant, settlement_settler, settlement_settlee"
          param :viewer_role, String, desc: "Viewer's role: owner, payer, participant, settler, settlee"
          param :summary, Hash, desc: "Viewer-relative summary for display" do
            param :label, String, desc: "Human-readable label (e.g. 'you lent', 'you owe', 'you paid')"
            param :amount_cents, Integer, desc: "Viewer-relevant amount in cents"
            param :paid_by_label, String, desc: "'You' or the payer's name"
          end
          param :paid_by, Hash, desc: "The user who paid" do
            param :id, Integer, desc: "User ID"
            param :name, String, desc: "Display name"
            param :is_you, :bool, desc: "True when the viewer is the payer"
          end
          param :account, Hash, desc: "Source account { id, name }" do
            param :id, Integer, desc: "Account ID"
            param :name, String, desc: "Account name"
          end
          param :transfer_to_account, Hash, desc: "Destination account { id, name } for transfers, or null"
          param :category, Hash, desc: "Category { id, name }, or null"
          param :counterpart, Hash, desc: "The other party { id, name } for settlements, or null"
          param :split_method, String, desc: "equal, exact, percentage, or shares (null for non-shared expenses)"
          param :splits, Array, desc: "Split details for shared expenses, null otherwise" do
            param :user, Hash, desc: "Participant" do
              param :id, Integer, desc: "User ID"
              param :name, String, desc: "Display name"
              param :is_you, :bool, desc: "True when this split belongs to the viewer"
            end
            param :owed_amount_cents, Integer, desc: "Amount owed by this participant, in cents"
            param :allocation_value, Float, desc: "Raw allocation value (null for equal splits)"
            param :category, Hash, desc: "Participant's category { id, name }, or null"
          end
        end
      end
    end
    def show
      Api::V0::Groups::Show.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :POST, "/v0/groups", "Create a new group"
    description <<~DESC
      Creates a new group. The authenticated user becomes the creator and is automatically added as a member.

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        name: string;
        description?: string;
        user_ids?: number[];
      };

      // Output
      type Response = {
        success: boolean;
        group: Group;
      };

      type Group = {
        id: number;
        name: string;
        description: string | null;
        created_by_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
        members: Member[];
      };

      type Member = {
        id: number;
        full_name: string;
        mobile_number: string;
        email: string;
        role: string;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :name, String, required: true, description: "Group name"
    param :description, String, required: false, description: "Optional group description"
    param :user_ids, Array, required: false, description: "Optional array of user IDs to add as members upon creation"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 422, desc: "Validation errors — e.g. one or more users do not exist"
    returns code: 201, desc: "Group created" do
      param :success, :bool, desc: "Operation status"
      param :group, Hash, desc: "Created group data" do
        param :id, Integer, desc: "Group ID"
        param :name, String, desc: "Group name"
        param :description, String, desc: "Group description"
        param :created_by_id, Integer, desc: "ID of the user who created the group"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :members, Array, desc: "List of group members" do
          param :id, Integer, desc: "Member user ID"
          param :full_name, String, desc: "Member full name"
          param :mobile_number, String, desc: "Member mobile number"
          param :email, String, desc: "Member email address"
          param :role, String, desc: "Member role in the group (e.g. 'creator', 'member')"
          param :created_at, String, desc: "ISO 8601 timestamp when the member was added to the group"
          param :updated_at, String, desc: "ISO 8601 timestamp when the member's role was last updated"
        end
      end
    end
    def create
      Api::V0::Groups::Create.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :PATCH, "/v0/groups/:id", "Update an existing group"
    description <<~DESC
      Updates an existing group. Only the group creator can update it.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        name?: string;
        description?: string;
      };

      // Output
      type Response = {
        success: boolean;
        group: Group;
      };

      type Group = {
        id: number;
        name: string;
        description: string | null;
        created_by_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
        members: Member[];
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Group ID"
    param :name, String, required: false, description: "Group name"
    param :description, String, required: false, description: "Group description"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Group not found"
    error code: 422, desc: "Validation errors"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :group, Hash, desc: "Updated group data" do
        param :id, Integer, desc: "Group ID"
        param :name, String, desc: "Group name"
        param :description, String, desc: "Group description"
        param :created_by_id, Integer, desc: "ID of the user who created the group"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :members, Array, desc: "List of group members" do
          param :id, Integer, desc: "Member user ID"
          param :full_name, String, desc: "Member full name"
          param :mobile_number, String, desc: "Member mobile number"
          param :email, String, desc: "Member email address"
          param :role, String, desc: "Member role in the group (e.g. 'creator', 'member')"
          param :created_at, String, desc: "ISO 8601 timestamp when the member was added to the group"
          param :updated_at, String, desc: "ISO 8601 timestamp when the member's role was last updated"
        end
      end
    end
    def update
      Api::V0::Groups::Update.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/groups/:id", "Delete a group"
    description <<~DESC
      Permanently deletes a group and all its memberships. Only the group creator can delete it.

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
    param :id, Integer, required: true, description: "Group ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Group not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
    end
    def destroy
      Api::V0::Groups::Destroy.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :POST, "/v0/groups/:id/members", "Add members to a group"
    description <<~DESC
      Adds one or more users to the group. Only the group creator can add members.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        user_ids: number[];
      };

      // Output
      type Response = {
        success: boolean;
        group: Group;
      };

      type Group = {
        id: number;
        name: string;
        description: string | null;
        created_by_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
        members: Member[];
      };

      type Member = {
        id: number;
        full_name: string;
        mobile_number: string;
        email: string;
        role: string;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Group ID"
    param :user_ids, Array, required: true, description: "Array of user IDs to add to the group"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Group not found"
    error code: 422, desc: "Validation errors — e.g. one or more users do not exist"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :group, Hash, desc: "Updated group data with new members" do
        param :id, Integer, desc: "Group ID"
        param :name, String, desc: "Group name"
        param :description, String, desc: "Group description"
        param :created_by_id, Integer, desc: "ID of the user who created the group"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :members, Array, desc: "List of group members" do
          param :id, Integer, desc: "Member user ID"
          param :full_name, String, desc: "Member full name"
          param :mobile_number, String, desc: "Member mobile number"
          param :email, String, desc: "Member email address"
          param :role, String, desc: "Member role in the group (e.g. 'creator', 'member')"
          param :created_at, String, desc: "ISO 8601 timestamp when the member was added to the group"
          param :updated_at, String, desc: "ISO 8601 timestamp when the member's role was last updated"
        end
      end
    end
    def add_members
      Api::V0::Groups::AddMembers.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/groups/:id/members/:user_id", "Remove a member from a group"
    description <<~DESC
      Removes a specific user from the group. Only the group creator can remove members.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = {
        id: number;      // Group ID
        user_id: number; // User ID to remove
      };

      // Output
      type Response = {
        success: boolean;
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Group ID"
    param :user_id, Integer, required: true, description: "ID of the user to remove"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Group or member not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :group, Hash, desc: "Updated group data with new members" do
        param :id, Integer, desc: "Group ID"
        param :name, String, desc: "Group name"
        param :description, String, desc: "Group description"
        param :created_by_id, Integer, desc: "ID of the user who created the group"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :members, Array, desc: "List of group members" do
          param :id, Integer, desc: "Member user ID"
          param :full_name, String, desc: "Member full name"
          param :mobile_number, String, desc: "Member mobile number"
          param :email, String, desc: "Member email address"
          param :role, String, desc: "Member role in the group (e.g. 'creator', 'member')"
          param :created_at, String, desc: "ISO 8601 timestamp when the member was added to the group"
          param :updated_at, String, desc: "ISO 8601 timestamp when the member's role was last updated"
        end
      end
    end
    def remove_member
      Api::V0::Groups::RemoveMember.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/groups/:id/leave", "Leave a group"
    description <<~DESC
      Removes the authenticated user from the group.

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
    param :id, Integer, required: true, description: "Group ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 404, desc: "Group not found or user is not a member"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
    end
    def leave
      Api::V0::Groups::Leave.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
