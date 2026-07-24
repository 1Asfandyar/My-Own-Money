# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Transactions", type: :request do
  let(:headers)      { { "Content-Type" => "application/json" } }
  let(:user)         { create(:user) }
  let(:currency)     { create(:currency) }
  let(:account)      { create(:account, user: user) }
  let(:category)     { create(:category, user: user) }
  let(:transaction)  { create(:transaction, user: user, account: account, category: category) }

  describe "GET /api/v0/transactions/:id" do
    let(:endpoint)        { "/api/v0/transactions/#{transaction.id}" }
    let(:request_headers) { headers }

    before do
      get endpoint, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated and the transaction belongs to the user" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/show_response")
      end

      it "returns the correct transaction" do
        expect(JSON.parse(response.body)["transaction"]["id"]).to eq(transaction.id)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the transaction belongs to another user" do
      let(:other_user)      { create(:user) }
      let(:other_account)   { create(:account, user: other_user) }
      let(:other_transaction) { create(:transaction, user: other_user, account: other_account) }
      let(:endpoint)        { "/api/v0/transactions/#{other_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the transaction does not exist" do
      let(:endpoint)        { "/api/v0/transactions/0" }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
