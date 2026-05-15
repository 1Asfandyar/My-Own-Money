# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Categories", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "GET /api/v0/categories" do
    let(:endpoint)        { "/api/v0/categories" }
    let(:request_headers) { headers }

    before { get endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("categories/index_response")
      end

      it "returns the user's predefined categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].size).to eq(Categories::Defaults.all.size)
        expect(data["categories"].map { |category| category["user_id"] }.uniq).to eq([ user.id ])
      end
    end

    context "when authenticated with existing categories" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user)      { create(:user) }
      let!(:own_categories)   { create_list(:category, 2, user: user) }
      let!(:other_category)   { create(:category, user: other_user) }

      before { get endpoint, headers: request_headers }

      it "returns only the current user's categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].size).to eq(Categories::Defaults.all.size + 2)
        expect(data["categories"].map { |c| c["id"] }).to include(*own_categories.map(&:id))
        expect(data["categories"].map { |c| c["user_id"] }.uniq).to eq([ user.id ])
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
