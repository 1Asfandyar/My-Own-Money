# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Categories", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "POST /api/v0/categories" do
    let(:endpoint)        { "/api/v0/categories" }
    let(:request_headers) { headers }
    let(:name)            { "Groceries" }
    let(:category_type)   { "expense" }

    let(:request_params) do
      { name: name, category_type: category_type }
    end

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with valid params" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("categories/create_response")
      end

      it "persists the category belonging to the current user" do
        expect(Category.find_by(name: name, user_id: user.id)).to be_present
      end
    end

    context "when authenticated with income type" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:category_type)   { "income" }

      it "returns 201 and persists income category" do
        expect(response).to have_http_status(:created)
        expect(Category.find_by(name: name, category_type: "income")).to be_present
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when name is blank" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:name)            { "" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category_type is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:category_type)   { "savings" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category_type is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { name: name } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
