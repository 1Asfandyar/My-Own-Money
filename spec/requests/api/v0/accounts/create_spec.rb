# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Accounts", type: :request do
  let(:headers)  { { "Content-Type" => "application/json" } }
  let(:user)     { create(:user) }
  let(:currency) { create(:currency) }

  describe "POST /api/v0/accounts" do
    let(:endpoint)        { "/api/v0/accounts" }
    let(:request_headers) { headers }
    let(:name)            { "My Wallet" }
    let(:currency_id)     { currency.id }

    let(:request_params) do
      { account: { name: name, currency_id: currency_id } }
    end

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with valid params" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("accounts/create_response")
      end

      it "persists the account belonging to the current user" do
        expect(Account.find_by(name: name, user_id: user.id)).to be_present
      end
    end

    context "when authenticated with optional balance params" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        { account: { name: name, currency_id: currency_id, initial_balance_cents: 5000, current_balance_cents: 5000 } }
      end

      it "returns 201 and persists balance values" do
        expect(response).to have_http_status(:created)
        account = Account.find_by(name: name)
        expect(account.initial_balance_cents).to eq(5000)
        expect(account.current_balance_cents).to eq(5000)
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

    context "when currency_id does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:currency_id)     { 0 }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
