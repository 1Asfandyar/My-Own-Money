# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Accounts", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:currency)        { create(:currency) }
  let!(:account)        { create(:account, user: user, currency: currency) }
  let(:request_headers) { headers }
  let(:new_name)        { "Updated Account Name" }

  let(:request_params) do
    { name: new_name }
  end

  describe "PATCH /api/v0/accounts/:id" do
    let(:endpoint) { "/api/v0/accounts/#{account.id}" }

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated as the account owner" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("accounts/update_response")
      end

      it "persists the updated name" do
        expect(account.reload.name).to eq(new_name)
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

    context "when account does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/accounts/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
