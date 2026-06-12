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
    context "when authenticated as a group member with no transactions" do
      before { get endpoint, headers: headers.merge(auth_headers(user)) }

      it "returns 200 with an empty transactions array" do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).dig("group", "transactions")).to eq([])
      end

      it "returns settled_up member_balances" do
        balances = JSON.parse(response.body).dig("group", "member_balances")
        expect(balances["overall"]).to include("type" => "settled_up", "amount_cents" => 0)
        expect(balances["per_member"]).to eq([])
      end
    end

    context "when authenticated as a group member with shared transactions (split partner not a group member)" do
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

      it "shows settled_up overall when split partner is not a group member" do
        balances = JSON.parse(response.body).dig("group", "member_balances")
        expect(balances["overall"]).to include("type" => "settled_up", "amount_cents" => 0)
        expect(balances["per_member"]).to eq([])
      end
    end

    context "when current user is the payer and the split partner is a group member" do
      let(:other_user)   { create(:user) }
      let!(:membership2) { create(:groups_user, group: group, user: other_user) }

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

      it "shows owes_you overall and from_user/to_user entry with is_you on to_user" do
        balances = JSON.parse(response.body).dig("group", "member_balances")
        expect(balances["overall"]).to include("type" => "owes_you", "amount_cents" => 500)

        entry = balances["per_member"].first
        expect(entry["from_user"]).to include("id" => other_user.id, "is_you" => false)
        expect(entry["to_user"]).to   include("id" => user.id,       "is_you" => true)
        expect(entry["amount_cents"]).to eq(500)
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

      it "shows you_owe overall and from_user/to_user entry with is_you on from_user" do
        balances = JSON.parse(response.body).dig("group", "member_balances")
        expect(balances["overall"]).to include("type" => "you_owe", "amount_cents" => 500)

        entry = balances["per_member"].first
        expect(entry["from_user"]).to include("id" => user.id,       "is_you" => true)
        expect(entry["to_user"]).to   include("id" => other_user.id, "is_you" => false)
        expect(entry["amount_cents"]).to eq(500)
      end
    end

    context "when balances cancel out (mutual transactions between two members)" do
      let(:other_user)    { create(:user) }
      let(:other_account) { create(:account, user: other_user, currency: currency) }
      let!(:membership2)  { create(:groups_user, group: group, user: other_user) }

      before do
        txn1 = create(:transaction, :shared, user: user, account: account,
                       currency: currency, group: group, amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn1, user: user, owed_amount_cents: 500)
        create(:transaction_split, financial_transaction: txn1, user: other_user, owed_amount_cents: 500)

        txn2 = create(:transaction, :shared, user: other_user, account: other_account,
                       currency: currency, group: group, amount_cents: 1000)
        create(:transaction_split, financial_transaction: txn2, user: other_user, owed_amount_cents: 500)
        create(:transaction_split, financial_transaction: txn2, user: user, owed_amount_cents: 500)

        get endpoint, headers: headers.merge(auth_headers(user))
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/show_response")
      end

      it "shows settled_up overall and empty per_member" do
        balances = JSON.parse(response.body).dig("group", "member_balances")
        expect(balances["overall"]).to include("type" => "settled_up", "amount_cents" => 0)
        expect(balances["per_member"]).to eq([])
      end
    end

    context "when there are three members with third-party balances" do
      # Group: user (U1), user2 (U2), user3 (U3)
      # txn1: U1 pays 900 → U1 owes 300 (own), U2 owes 300, U3 owes 300
      # txn2: U2 pays 600 → U2 owes 200 (own), U1 owes 200, U3 owes 200
      # Debt calc (own splits excluded by ts.user_id != t.user_id):
      #   U2 owes U1 300; U3 owes U1 300; U1 owes U2 200; U3 owes U2 200
      # Per-pair:
      #   U1 vs U2: 300 - 200 = 100 → U2 owes U1 100  (owes_you, to_user.is_you true)
      #   U1 vs U3: 300 - 0   = 300 → U3 owes U1 300  (owes_you, to_user.is_you true)
      #   U2 vs U3: 0   - 200 = -200 → U3 owes U2 200 (third-party, both is_you false)
      # U1 overall: +100 + 300 = 400 owes_you

      let(:user2)         { create(:user) }
      let(:user3)         { create(:user) }
      let(:account2)      { create(:account, user: user2, currency: currency) }
      let!(:membership2)  { create(:groups_user, group: group, user: user2) }
      let!(:membership3)  { create(:groups_user, group: group, user: user3) }

      before do
        txn1 = create(:transaction, :shared, user: user, account: account,
                       currency: currency, group: group, amount_cents: 900)
        create(:transaction_split, financial_transaction: txn1, user: user,  owed_amount_cents: 300)
        create(:transaction_split, financial_transaction: txn1, user: user2, owed_amount_cents: 300)
        create(:transaction_split, financial_transaction: txn1, user: user3, owed_amount_cents: 300)

        txn2 = create(:transaction, :shared, user: user2, account: account2,
                       currency: currency, group: group, amount_cents: 600)
        create(:transaction_split, financial_transaction: txn2, user: user2, owed_amount_cents: 200)
        create(:transaction_split, financial_transaction: txn2, user: user,  owed_amount_cents: 200)
        create(:transaction_split, financial_transaction: txn2, user: user3, owed_amount_cents: 200)

        get endpoint, headers: headers.merge(auth_headers(user))
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/show_response")
      end

      it "shows overall owes_you 400 for current user" do
        overall = JSON.parse(response.body).dig("group", "member_balances", "overall")
        expect(overall).to include("type" => "owes_you", "amount_cents" => 400)
      end

      it "includes all three pairwise balance entries" do
        per_member = JSON.parse(response.body).dig("group", "member_balances", "per_member")
        expect(per_member.size).to eq(3)
      end

      it "includes the third-party pair (user3 owes user2) with both is_you false" do
        per_member = JSON.parse(response.body).dig("group", "member_balances", "per_member")
        third_party = per_member.find { |e| !e["from_user"]["is_you"] && !e["to_user"]["is_you"] }
        expect(third_party).not_to be_nil
        expect(third_party["from_user"]["id"]).to eq(user3.id)
        expect(third_party["to_user"]["id"]).to   eq(user2.id)
        expect(third_party["amount_cents"]).to eq(200)
      end

      it "marks is_you correctly on pairs involving current user" do
        per_member = JSON.parse(response.body).dig("group", "member_balances", "per_member")
        my_pairs = per_member.select { |e| e["from_user"]["is_you"] || e["to_user"]["is_you"] }
        expect(my_pairs.size).to eq(2)
        my_pairs.each do |e|
          expect(e["to_user"]["is_you"]).to   be(true)
          expect(e["from_user"]["is_you"]).to be(false)
        end
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
