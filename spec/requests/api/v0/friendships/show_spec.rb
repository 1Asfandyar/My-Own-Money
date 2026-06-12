# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Friendships", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }
  let(:friend)  { create(:user) }
  let!(:friendship) { create(:friendship, :accepted, sender: user, receiver: friend) }

  # Seeding hooks at this (outer) level run before the inner describe's before { get } block.
  # Nested contexts override these lazy lets to inject data before the request fires.
  let(:debt)         { nil }
  let!(:_setup_debt) { debt }

  # extra_setup is a lambda/block returning arbitrary fixtures; nil means no extra data.
  let(:extra_setup) { nil }
  let!(:_extra_setup) { extra_setup }

  describe "GET /api/v0/friendships/:id" do
    let(:endpoint)        { "/api/v0/friendships/#{friendship.id}" }
    let(:request_headers) { headers }

    before do
      get endpoint, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated as the initiating user" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/show_response")
      end

      it "returns the correct friend profile" do
        body = JSON.parse(response.body)
        expect(body["friendship"]["friend"]["id"]).to eq(friend.id)
        expect(body["friendship"]["friend"]["full_name"]).to eq(friend.full_name)
      end

      it "returns settled_up balance when no debts exist" do
        body = JSON.parse(response.body)
        expect(body["friendship"]["balance_summary"]["type"]).to eq("settled_up")
        expect(body["friendship"]["balance_summary"]["amount_cents"]).to eq(0)
      end

      it "returns empty group_balances when no shared groups" do
        expect(JSON.parse(response.body)["friendship"]["group_balances"]).to eq([])
      end

      it "returns empty transactions when no shared transactions" do
        expect(JSON.parse(response.body)["friendship"]["transactions"]).to eq([])
      end
    end

    context "when authenticated as the other party (user_b)" do
      let(:request_headers) { headers.merge(auth_headers(friend)) }

      it "returns 200 and matches schema from friend's perspective" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/show_response")
        expect(JSON.parse(response.body)["friendship"]["friend"]["id"]).to eq(user.id)
      end
    end

    context "when the friend owes the current user" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:debt) { create(:debt, from_user: friend, to_user: user, amount_cents: 750) }

      it "returns owes_you balance with correct amount" do
        body = JSON.parse(response.body)
        expect(body["friendship"]["balance_summary"]["type"]).to eq("owes_you")
        expect(body["friendship"]["balance_summary"]["amount_cents"]).to eq(750)
      end
    end

    context "when the current user owes the friend" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:debt) { create(:debt, from_user: user, to_user: friend, amount_cents: 400) }

      it "returns you_owe balance with correct amount" do
        body = JSON.parse(response.body)
        expect(body["friendship"]["balance_summary"]["type"]).to eq("you_owe")
        expect(body["friendship"]["balance_summary"]["amount_cents"]).to eq(400)
      end
    end

    context "when the current user paid in a shared group transaction" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:extra_setup) do
        currency     = create(:currency)
        user_account = create(:account, user: user, currency: currency)
        group        = create(:group, created_by: user)
        create(:groups_user, group: group, user: user)
        create(:groups_user, group: group, user: friend)
        txn = create(:transaction, :shared, user: user, group: group,
                     account: user_account, currency: currency, amount_cents: 3000)
        create(:transaction_split, financial_transaction: txn, user: user,
               owed_amount_cents: 1500)
        create(:transaction_split, financial_transaction: txn, user: friend,
               owed_amount_cents: 1500)
        { group: group, txn: txn }
      end

      it "returns owes_you group balance for that group" do
        body           = JSON.parse(response.body)
        group_balances = body["friendship"]["group_balances"]
        expect(group_balances.size).to eq(1)
        expect(group_balances.first["group_id"]).to eq(extra_setup[:group].id)
        expect(group_balances.first["group_name"]).to eq(extra_setup[:group].name)
        expect(group_balances.first["balance"]["type"]).to eq("owes_you")
        expect(group_balances.first["balance"]["amount_cents"]).to eq(1500)
      end

      it "returns the transaction with payer role and you_lent summary" do
        body         = JSON.parse(response.body)
        transactions = body["friendship"]["transactions"]
        expect(transactions.size).to eq(1)
        expect(transactions.first["id"]).to eq(extra_setup[:txn].id)
        expect(transactions.first["render_as"]).to eq("shared_expense_payer")
        expect(transactions.first["viewer_role"]).to eq("payer")
        expect(transactions.first["paid_by"]["id"]).to eq(user.id)
        expect(transactions.first["paid_by"]["is_you"]).to be true
        expect(transactions.first["summary"]["label"]).to eq("you lent")
        expect(transactions.first["summary"]["amount_cents"]).to eq(1500)
      end
    end

    context "when the friend paid in a shared group transaction" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:extra_setup) do
        currency       = create(:currency)
        friend_account = create(:account, user: friend, currency: currency)
        group          = create(:group, created_by: friend)
        create(:groups_user, group: group, user: user)
        create(:groups_user, group: group, user: friend)
        txn = create(:transaction, :shared, user: friend, group: group,
                     account: friend_account, currency: currency, amount_cents: 2000)
        create(:transaction_split, financial_transaction: txn, user: user,
               owed_amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn, user: friend,
               owed_amount_cents: 1000)
        { txn: txn }
      end

      it "returns you_owe group balance and participant role with you_owe summary" do
        body         = JSON.parse(response.body)
        transactions = body["friendship"]["transactions"]
        group_balances = body["friendship"]["group_balances"]
        expect(group_balances.first["balance"]["type"]).to eq("you_owe")
        expect(group_balances.first["balance"]["amount_cents"]).to eq(1000)
        expect(transactions.first["id"]).to eq(extra_setup[:txn].id)
        expect(transactions.first["render_as"]).to eq("shared_expense_participant")
        expect(transactions.first["viewer_role"]).to eq("participant")
        expect(transactions.first["summary"]["label"]).to eq("you owe")
        expect(transactions.first["summary"]["amount_cents"]).to eq(1000)
      end
    end

    context "when a third party paid in a shared group transaction" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:extra_setup) do
        third_party         = create(:user)
        currency            = create(:currency)
        third_party_account = create(:account, user: third_party, currency: currency)
        group               = create(:group, created_by: third_party)
        create(:groups_user, group: group, user: user)
        create(:groups_user, group: group, user: friend)
        create(:groups_user, group: group, user: third_party)
        txn = create(:transaction, :shared, user: third_party, group: group,
                     account: third_party_account, currency: currency, amount_cents: 3000)
        create(:transaction_split, financial_transaction: txn, user: user,
               owed_amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn, user: friend,
               owed_amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn, user: third_party,
               owed_amount_cents: 1000)
        {}
      end

      it "returns participant role for the transaction and excludes group from balances" do
        body         = JSON.parse(response.body)
        transactions = body["friendship"]["transactions"]
        expect(transactions.first["render_as"]).to eq("shared_expense_participant")
        expect(transactions.first["viewer_role"]).to eq("participant")
        expect(body["friendship"]["group_balances"]).to eq([])
      end
    end

    context "when group balances net to zero" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:extra_setup) do
        currency       = create(:currency)
        user_account   = create(:account, user: user, currency: currency)
        friend_account = create(:account, user: friend, currency: currency)
        group          = create(:group, created_by: user)
        create(:groups_user, group: group, user: user)
        create(:groups_user, group: group, user: friend)
        txn1 = create(:transaction, :shared, user: user, group: group,
                      account: user_account, currency: currency, amount_cents: 2000)
        create(:transaction_split, financial_transaction: txn1, user: user,
               owed_amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn1, user: friend,
               owed_amount_cents: 1000)
        txn2 = create(:transaction, :shared, user: friend, group: group,
                      account: friend_account, currency: currency, amount_cents: 2000)
        create(:transaction_split, financial_transaction: txn2, user: user,
               owed_amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn2, user: friend,
               owed_amount_cents: 1000)
        {}
      end

      it "excludes the group from group_balances but includes both transactions" do
        body = JSON.parse(response.body)
        expect(body["friendship"]["group_balances"]).to eq([])
        expect(body["friendship"]["transactions"].size).to eq(2)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the friendship does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/friendships/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when a user not involved in the friendship requests it" do
      let(:outsider)        { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(outsider)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
