module Api::V0
  class CategoriesController < ApiController
    resource_description do
      short "Categories management"
      description "Manage expense and income categories for the current user. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/categories", "List all categories for the current user"
    description <<~DESC
      Returns all categories belonging to the authenticated user. New users receive predefined categories automatically.

      **TypeScript Types**

      ```typescript
      // Input: none (authenticated via JWT header)

      // Output
      type Response = {
        success: boolean;
        categories: Category[];
      };

      type Category = {
        id: number;
        name: string;
        icon: string | null;
        color: string | null;
        balance_cents: number;
        category_type: 'expense' | 'income';
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
      param :categories, Array, desc: "List of categories" do
        param :id, Integer, desc: "Category ID"
        param :name, String, desc: "Category name"
        param :icon, String, desc: "Optional Material icon name"
        param :color, String, desc: "Optional hex color"
        param :balance_cents, Integer, desc: "Current balance in cents"
        param :category_type, String, desc: "Category type: 'expense' or 'income'"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def index
      Api::V0::Categories::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :GET, "/v0/categories/:id", "Get a specific category"
    description <<~DESC
      Returns a single category by ID. Only accessible if the category belongs to the current user.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };

      // Output
      type Response = {
        success: boolean;
        category: Category;
      };

      type Category = {
        id: number;
        name: string;
        icon: string | null;
        color: string | null;
        balance_cents: number;
        category_type: 'expense' | 'income';
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Category ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Category not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :category, Hash, desc: "Category data" do
        param :id, Integer, desc: "Category ID"
        param :name, String, desc: "Category name"
        param :icon, String, desc: "Optional Material icon name"
        param :color, String, desc: "Optional hex color"
        param :balance_cents, Integer, desc: "Current balance in cents"
        param :category_type, String, desc: "Category type: 'expense' or 'income'"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def show
      Api::V0::Categories::Show.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :POST, "/v0/categories", "Create a new category"
    description <<~DESC
      Creates a new category for the authenticated user.

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        name: string;
        category_type: 'expense' | 'income';
        icon?: string | null;
        color?: string | null;
      };

      // Output
      type Response = {
        success: boolean;
        category: Category;
      };

      type Category = {
        id: number;
        name: string;
        icon: string | null;
        color: string | null;
        category_type: 'expense' | 'income';
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    param :name, String, required: true, description: "Category name"
    param :category_type, String, required: true, description: "Category type: 'expense' or 'income'"
    param :icon, String, required: false, description: "Optional Material icon name"
    param :color, String, required: false, description: "Optional hex color"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 422, desc: "Validation errors"
    returns code: 201, desc: "Category created" do
      param :success, :bool, desc: "Operation status"
      param :category, Hash, desc: "Created category data" do
        param :id, Integer, desc: "Category ID"
        param :name, String, desc: "Category name"
        param :icon, String, desc: "Optional Material icon name"
        param :color, String, desc: "Optional hex color"
        param :category_type, String, desc: "Category type: 'expense' or 'income'"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def create
      Api::V0::Categories::Create.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :PATCH, "/v0/categories/:id", "Update an existing category"
    description <<~DESC
      Updates an existing category. Only fields provided will be updated.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };
      type Body = {
        name?: string;
        category_type?: 'expense' | 'income';
        icon?: string | null;
        color?: string | null;
      };

      // Output
      type Response = {
        success: boolean;
        category: Category;
      };

      type Category = {
        id: number;
        name: string;
        icon: string | null;
        color: string | null;
        category_type: 'expense' | 'income';
        user_id: number;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
        balance_cents: number; // Current balance in cents
      };
      ```
    DESC
    param :id, Integer, required: true, description: "Category ID"
    param :name, String, required: false, description: "Category name"
    param :category_type, String, required: false, description: "Category type: 'expense' or 'income'"
    param :icon, String, required: false, description: "Optional Material icon name"
    param :color, String, required: false, description: "Optional hex color"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Category not found"
    error code: 422, desc: "Validation errors"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :category, Hash, desc: "Updated category data" do
        param :id, Integer, desc: "Category ID"
        param :name, String, desc: "Category name"
        param :icon, String, desc: "Optional Material icon name"
        param :color, String, desc: "Optional hex color"
        param :category_type, String, desc: "Category type: 'expense' or 'income'"
        param :user_id, Integer, desc: "Owner user ID"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
        param :balance_cents, Integer, desc: "Current balance in cents"
      end
    end
    def update
      Api::V0::Categories::Update.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/categories/:id", "Delete a category"
    description <<~DESC
      Permanently deletes a category. This action cannot be undone.

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
    param :id, Integer, required: true, description: "Category ID"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    error code: 404, desc: "Category not found"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
    end
    def destroy
      Api::V0::Categories::Destroy.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
