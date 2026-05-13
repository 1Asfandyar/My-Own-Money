# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Categories", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let!(:category)       { create(:category, user: user, name: "Old Name", category_type: :expense) }
  let(:request_headers) { headers }
  let(:new_name)        { "New Name" }

  let(:request_params) do
    { name: new_name }
  end

  describe "PATCH /api/v0/categories/:id" do
    let(:endpoint) { "/api/v0/categories/#{category.id}" }

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated as the category owner" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("categories/update_response")
      end

      it "persists the updated name" do
        expect(category.reload.name).to eq(new_name)
      end
    end

    context "when updating category_type" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_type: "income" } }

      it "returns 200 and updates the type" do
        expect(response).to have_http_status(:ok)
        expect(category.reload.category_type).to eq("income")
      end
    end

    context "when updating icon and color" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { icon: "local_cafe", color: "#FFA366" } }

      it "returns 200 and updates the metadata" do
        expect(response).to have_http_status(:ok)
        expect(category.reload.icon).to eq("local_cafe")
        expect(category.color).to eq("#FFA366")
      end
    end

    context "when clearing icon and color" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:category)        { create(:category, user: user, icon: "local_cafe", color: "#FFA366") }
      let(:request_params)  { { icon: nil, color: nil } }

      it "returns 200 and clears the metadata" do
        expect(response).to have_http_status(:ok)
        expect(category.reload.icon).to be_nil
        expect(category.color).to be_nil
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when authenticated as a different user" do
      let(:other_user)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(other_user)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/categories/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category_type is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_type: "savings" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when color is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { color: "red" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
