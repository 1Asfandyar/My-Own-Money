module Api::V0
  class CurrenciesController < ApiController
    resource_description do
      short "Currencies"
      description "List supported currencies. This endpoint requires JWT authentication."
      api_version "v0"
    end

    api :GET, "/api/v0/currencies", "List supported currencies"
    description <<~DESC
      Returns all supported currencies ordered by currency code ascending.

      **TypeScript Types**

      ```typescript
      // Input: none (authenticated via JWT header)

      // Output
      type Response = {
        success: boolean;
        currencies: Currency[];
      };

      type Currency = {
        id: number;
        code: string;
        name: string;
        symbol: string;
        created_at: string; // ISO 8601
        updated_at: string; // ISO 8601
      };
      ```
    DESC
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — insufficient permissions"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :currencies, Array, desc: "List of supported currencies" do
        param :id, Integer, desc: "Currency ID"
        param :code, String, desc: "Currency code"
        param :name, String, desc: "Currency name"
        param :symbol, String, desc: "Currency symbol"
        param :created_at, String, desc: "ISO 8601 creation timestamp"
        param :updated_at, String, desc: "ISO 8601 last-update timestamp"
      end
    end
    def index
      Api::V0::Currencies::Index.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end
