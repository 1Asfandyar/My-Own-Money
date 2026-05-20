module Api::V0
  class FriendshipsController < ApiController
    before_action :require_current_user!

    resource_description do
      short "Friendships management"
      description "Manage friend requests and friendships. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/friendships", "List friendships for the current user"
    description <<~DESC
      Returns friendships involving the authenticated user. By default returns accepted friends.
      Use `filter` to see incoming or outgoing pending requests. Use `status` to override the default
      status filter. Both filters can be combined.

      **TypeScript Types**

      ```typescript
      // Query Params
      type Params = {
        filter?: "incoming" | "outgoing"; // incoming = received by me, outgoing = sent by me
        status?: "pending" | "accepted" | "blocked";
      };

      // Output
      type Response = {
        success: boolean;
        friendships: Friendship[];
      };

      type Friendship = {
        id: number;
        status: "pending" | "accepted" | "blocked";
        requested_by_id: number;
        friend: User;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };

      type User = {
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
    param :filter, String, required: false, desc: "Direction filter: 'incoming' (requests sent to me) or 'outgoing' (requests I sent)"
    param :status, String, required: false, desc: "Status filter: 'pending', 'accepted', or 'blocked'. Defaults to 'accepted' when no filter is given"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 422, desc: "Validation error — invalid filter or status value"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :friendships, Array, desc: "List of friendships" do
        param :id, Integer, desc: "Friendship ID"
        param :status, String, desc: "Friendship status: pending, accepted, or blocked"
        param :requested_by_id, Integer, desc: "ID of the user who sent the friend request"
        param :friend, Hash, desc: "The other user in the friendship" do
          param :id, Integer, desc: "User ID"
          param :full_name, String, desc: "Full name"
          param :email, String, desc: "Email address"
        end
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def index
      Api::V0::Friendships::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :POST, "/v0/friendships", "Send friend requests to multiple users"
    description <<~DESC
      Creates pending friend requests to the given users. Already-existing friendships are silently
      skipped. Returns only the newly created friendship records.

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        user_ids: number[];
      };

      // Output
      type Response = {
        success: boolean;
        friendships: Friendship[];
      };

      type Friendship = {
        id: number;
        status: "pending";
        requested_by_id: number;
        friend: User;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :user_ids, Array, of: Integer, required: true, desc: "Array of user IDs to send friend requests to"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 422, desc: "Validation error — one or more user IDs do not exist"
    returns code: 201, desc: "Friend requests created" do
      param :success, :bool, desc: "Operation status"
      param :friendships, Array, desc: "Newly created friendship records" do
        param :id, Integer, desc: "Friendship ID"
        param :status, String, desc: "Always 'pending' for new requests"
        param :requested_by_id, Integer, desc: "ID of the user who sent the request (current user)"
        param :friend, Hash, desc: "The other user in the friendship" do
          param :id, Integer, desc: "User ID"
          param :full_name, String, desc: "Full name"
          param :email, String, desc: "Email address"
        end
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def create
      Api::V0::Friendships::Create.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :PATCH, "/v0/friendships/:id", "Update the status of a friendship"
    description <<~DESC
      Updates the status of a friendship. Rules:
      - `accepted` — only the user who received the request (non-requester) can accept
      - `rejected` — only the user who received the request can reject (deletes the record)
      - `blocked`  — either party can block at any time

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        status: "accepted" | "blocked" | "rejected";
      };

      // Output (accepted / blocked)
      type Response = {
        success: boolean;
        friendship: Friendship;
      };

      // Output (rejected — record is deleted)
      type Response = {
        success: boolean;
      };
      ```
    DESC
    param :id, Integer, required: true, desc: "Friendship ID"
    param :status, String, required: true, desc: "New status: 'accepted', 'blocked', or 'rejected'"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — you are not allowed to perform this status transition"
    error code: 404, desc: "Friendship not found or does not involve the current user"
    error code: 422, desc: "Validation error — invalid status value"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :friendship, Hash, desc: "Updated friendship (absent when status is 'rejected')" do
        param :id, Integer, desc: "Friendship ID"
        param :status, String, desc: "Updated status"
        param :requested_by_id, Integer, desc: "ID of the original requester"
        param :friend, Hash, desc: "The other user in the friendship" do
          param :id, Integer, desc: "User ID"
          param :full_name, String, desc: "Full name"
          param :email, String, desc: "Email address"
        end
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def update
      Api::V0::Friendships::Update.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/friendships/:id", "Delete a pending friend request"
    description <<~DESC
      Deletes a pending friend request. Only the user who sent the request can delete it,
      and only while the request is still pending.

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
    param :id, Integer, required: true, desc: "Friendship ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — you did not send this request, or it is no longer pending"
    error code: 404, desc: "Friendship not found or does not involve the current user"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
    end
    def destroy
      Api::V0::Friendships::Destroy.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
