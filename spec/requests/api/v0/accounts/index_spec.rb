# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Accounts", type: :request do
  let(:headers)  { { "Content-Type" => "application/json" } }
  let(:user)     { create(:user) }
  let(:currency) { create(:currency) }

  describe "GET /api/v0/accounts" do
    let(:endpoint)        { "/api/v0/accounts" }
    let(:request_headers) { headers }

    before { get endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("accounts/index_response")
      end

      it "returns an empty list when the user has no accounts" do
        data = JSON.parse(response.body)
        expect(data["accounts"]).to eq([])
      end
    end

    context "when authenticated with existing accounts" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user)      { create(:user) }
      let!(:own_accounts)   { create_list(:account, 2, user: user, currency: currency) }
      let!(:other_account)  { create(:account, user: other_user, currency: currency) }

      before { get endpoint, headers: request_headers }

      it "returns only the current user's accounts" do
        data = JSON.parse(response.body)
        expect(data["accounts"].size).to eq(2)
        expect(data["accounts"].map { |a| a["user_id"] }.uniq).to eq([ user.id ])
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
