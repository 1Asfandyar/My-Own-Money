# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:group)           { create(:group, created_by: user) }
  let!(:membership)     { create(:groups_user, group: group, user: user) }
  let(:currency)        { create(:currency) }
  let(:account)         { create(:account, user: user, currency: currency) }

  describe "GET /api/v0/groups/:id" do
    let(:endpoint) { "/api/v0/groups/#{group.id}" }

    # SUCCESS PATHS
    context "when authenticated as a group member with shared transactions" do
      let(:other_user) { create(:user) }

      before do
        shared_txn = create(:transaction, :shared, user: user, account: account,
                             currency: currency, group: group, amount_cents: 1000)
        create(:transaction_split, financial_transaction: shared_txn, user: user, owed_amount_cents: 500)
        create(:transaction_split, financial_transaction: shared_txn, user: other_user, owed_amount_cents: 500)
        get endpoint, headers: headers.merge(auth_headers(user))
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/show_response")
      end

      it "includes transactions in the rich formatter shape" do
        txns = JSON.parse(response.body).dig("group", "transactions")
        expect(txns.size).to eq(1)
        expect(txns.first).to include(
          "type"        => "expense",
          "visibility"  => "shared",
          "render_as"   => "shared_expense_payer",
          "viewer_role" => "payer"
        )
        expect(txns.first["summary"]).to include("label" => "you lent")
        expect(txns.first["splits"].size).to eq(2)
      end
    end

    context "when authenticated as a group member with no transactions" do
      before { get endpoint, headers: headers.merge(auth_headers(user)) }

      it "returns 200 with an empty transactions array" do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).dig("group", "transactions")).to eq([])
      end
    end

    context "when authenticated as a participant (non-payer) in a shared transaction" do
      let(:other_user)    { create(:user) }
      let(:other_account) { create(:account, user: other_user, currency: currency) }
      let!(:membership2)  { create(:groups_user, group: group, user: other_user) }

      before do
        shared_txn = create(:transaction, :shared, user: other_user, account: other_account,
                             currency: currency, group: group, amount_cents: 1000)
        create(:transaction_split, financial_transaction: shared_txn, user: other_user, owed_amount_cents: 500)
        create(:transaction_split, financial_transaction: shared_txn, user: user, owed_amount_cents: 500)
        get endpoint, headers: headers.merge(auth_headers(user))
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/show_response")
      end

      it "renders the transaction as shared_expense_participant" do
        txns = JSON.parse(response.body).dig("group", "transactions")
        expect(txns.first).to include(
          "render_as"   => "shared_expense_participant",
          "viewer_role" => "participant"
        )
        expect(txns.first["summary"]).to include("label" => "you owe")
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      before { get endpoint, headers: headers }

      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when authenticated as a non-member" do
      let(:other_user) { create(:user) }

      before { get endpoint, headers: headers.merge(auth_headers(other_user)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when group does not exist" do
      before { get "/api/v0/groups/0", headers: headers.merge(auth_headers(user)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
