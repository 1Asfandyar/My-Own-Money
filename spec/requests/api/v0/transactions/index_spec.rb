# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Transactions", type: :request do
  let(:headers)  { { "Content-Type" => "application/json" } }
  let(:user)     { create(:user) }
  let(:currency) { create(:currency) }
  let(:account)  { create(:account, user: user, currency: currency) }
  let(:category) { create(:category, user: user) }

  describe "GET /api/v0/transactions" do
    let(:endpoint)        { "/api/v0/transactions" }
    let(:request_headers) { headers }
    let(:request_params)  { {} }

    before do
      get endpoint, params: request_params, headers: request_headers
    end

    # SUCCESS PATHS

    context "when authenticated with no filters" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user) { create(:user) }
      let(:other_account) { create(:account, user: other_user, currency: currency) }

      before do
        create(:transaction, user: user, account: account, currency: currency, category: category,
               title: "Groceries", transaction_date: 2.days.ago)
        create(:transaction, user: user, account: account, currency: currency, category: category,
               title: "Rent", transaction_date: 1.day.ago)
        create(:transaction, user: other_user, account: other_account, currency: currency)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
      end

      it "excludes transactions the current user has no involvement in" do
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Groceries", "Rent")
        expect(titles.size).to eq(2)
      end
    end

    context "when another user created a shared expense with current user in the splits" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user) { create(:user) }
      let(:other_account) { create(:account, user: other_user, currency: currency) }
      let(:group) { create(:group) }

      before do
        shared_txn = create(:transaction, :shared, user: other_user, account: other_account,
                             currency: currency, title: "Shared Dinner", group: group)
        create(:transaction_split, financial_transaction: shared_txn, user: user,
               owed_amount_cents: 500)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns the shared transaction" do
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Shared Dinner")
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
      end
    end

    context "when another user created a settlement targeting current user" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user) { create(:user) }
      let(:other_account) { create(:account, user: other_user, currency: currency) }

      before do
        create(:transaction, :settlement, user: other_user, account: other_account,
               currency: currency, title: "Debt Repayment", settles_user: user)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns the settlement transaction" do
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Debt Repayment")
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
      end
    end

    context "when a shared expense has multiple splits for current user (deduplication)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user) { create(:user) }
      let(:other_account) { create(:account, user: other_user, currency: currency) }
      let(:group) { create(:group) }

      before do
        shared_txn = create(:transaction, :shared, user: other_user, account: other_account,
                             currency: currency, title: "Group Trip", group: group)
        create(:transaction_split, financial_transaction: shared_txn, user: user,
               owed_amount_cents: 300)
        create(:transaction_split, financial_transaction: shared_txn, user: other_user,
               owed_amount_cents: 300)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns the transaction only once" do
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles.count("Group Trip")).to eq(1)
      end
    end

    context "when filtered by account_id" do
      let(:other_account)  { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { account_id: account.id } }

      before do
        create(:transaction, user: user, account: account, currency: currency, category: category,
               transaction_type: :expense, amount_cents: 2_000)
        create(:transaction, user: user, account: other_account, currency: currency, category: category,
               transaction_type: :expense, amount_cents: 3_000)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200, matches schema, and returns only transactions for that account" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        account_ids = JSON.parse(response.body)["transactions"].map { |t| t.dig("account", "id") }.uniq
        expect(account_ids).to eq([ account.id ])
      end

      it "includes category info in display for each transaction" do
        transaction = JSON.parse(response.body)["transactions"].first

        expect(transaction.dig("category", "id")).to eq(category.id)
        expect(transaction["category"]).to include(
          "id"   => category.id,
          "name" => category.name
        )
      end
    end

    context "when filtered by transaction_type" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { transaction_type: "income" } }

      before do
        create(:transaction, user: user, account: account, currency: currency,
               transaction_type: :expense, title: "Groceries")
        create(:transaction, user: user, account: account, currency: currency,
               transaction_type: :income, title: "Salary")
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and only transactions of the requested type" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        types = JSON.parse(response.body)["transactions"].map { |t| t["type"] }.uniq
        expect(types).to eq([ "income" ])
      end
    end

    context "when filtered by visibility_type" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { visibility_type: "personal" } }
      let(:group)           { create(:group) }

      before do
        create(:transaction, user: user, account: account, currency: currency,
               visibility_type: :personal, title: "Personal Expense")
        shared_txn = create(:transaction, :shared, user: user, account: account,
                             currency: currency, title: "Group Dinner", group: group)
        create(:transaction_split, financial_transaction: shared_txn, user: user,
               owed_amount_cents: 500)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and only transactions with the requested visibility" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Personal Expense")
        expect(titles).not_to include("Group Dinner")
      end
    end

    context "when filtered by group_id" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:group)           { create(:group) }
      let(:other_group)     { create(:group) }
      let(:request_params)  { { group_id: group.id } }

      before do
        group_txn = create(:transaction, :shared, user: user, account: account,
                           currency: currency, title: "Group Expense", group: group)
        create(:transaction_split, financial_transaction: group_txn, user: user,
               owed_amount_cents: 500)
        other_txn = create(:transaction, :shared, user: user, account: account,
                           currency: currency, title: "Other Group Expense", group: other_group)
        create(:transaction_split, financial_transaction: other_txn, user: user,
               owed_amount_cents: 500)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and only transactions belonging to that group" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Group Expense")
        expect(titles).not_to include("Other Group Expense")
      end
    end

    context "when filtered by friend_id" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:friend)          { create(:user) }
      let(:friend_account)  { create(:account, user: friend, currency: currency) }
      let(:group)           { create(:group) }
      let(:request_params)  { { friend_id: friend.id } }

      before do
        shared_txn = create(:transaction, :shared, user: friend, account: friend_account,
                             currency: currency, title: "Shared with Friend", group: group)
        # Both current user AND friend need split rows for the friend_id filter to match
        create(:transaction_split, financial_transaction: shared_txn, user: user,
               owed_amount_cents: 500)
        create(:transaction_split, financial_transaction: shared_txn, user: friend,
               owed_amount_cents: 500)
        create(:transaction, user: user, account: account, currency: currency, title: "My Personal")
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and only transactions where both user and friend participated" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Shared with Friend")
        expect(titles).not_to include("My Personal")
      end
    end

    context "when filtered by friend_id and current user paid a settlement targeting the friend" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:friend)          { create(:user) }
      let(:request_params)  { { friend_id: friend.id } }

      before do
        create(:transaction, :settlement, user: user, account: account,
               currency: currency, title: "I Settled with Friend", settles_user: friend)
        create(:transaction, user: user, account: account, currency: currency, title: "My Personal")
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and includes the settlement" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("I Settled with Friend")
        expect(titles).not_to include("My Personal")
      end
    end

    context "when filtered by friend_id and the friend paid a settlement targeting the current user" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:friend)          { create(:user) }
      let(:friend_account)  { create(:account, user: friend, currency: currency) }
      let(:request_params)  { { friend_id: friend.id } }

      before do
        create(:transaction, :settlement, user: friend, account: friend_account,
               currency: currency, title: "Friend Settled with Me", settles_user: user)
        create(:transaction, user: user, account: account, currency: currency, title: "My Personal")
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and includes the settlement" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Friend Settled with Me")
        expect(titles).not_to include("My Personal")
      end
    end

    context "when paginated with per_page" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { per_page: 2, page: 1 } }

      before do
        3.times { |i| create(:transaction, user: user, account: account, currency: currency, transaction_date: i.days.ago) }
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and respects the per_page limit" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        expect(JSON.parse(response.body)["transactions"].size).to eq(2)
      end
    end

    context "when requesting page 2" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { per_page: 2, page: 2 } }

      before do
        3.times { |i| create(:transaction, user: user, account: account, currency: currency, transaction_date: i.days.ago) }
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and the remaining records" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
        expect(JSON.parse(response.body)["transactions"].size).to eq(1)
      end
    end

    context "when filtered by category_id" do
      let(:other_category)  { create(:category, user: user) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_id: category.id } }

      before do
        create(:transaction, user: user, account: account, currency: currency, category: category)
        create(:transaction, user: user, account: account, currency: currency, category: other_category)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns only transactions for that category" do
        expect(response).to have_http_status(:ok)
        category_ids = JSON.parse(response.body)["transactions"].map { |t| t.dig("category", "id") }.uniq
        expect(category_ids).to eq([ category.id ])
      end
    end

    context "when filtered by date range" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { date_from: 3.days.ago.iso8601, date_to: 1.day.ago.iso8601 } }

      before do
        create(:transaction, user: user, account: account, currency: currency,
               title: "Old",     transaction_date: 5.days.ago)
        create(:transaction, user: user, account: account, currency: currency,
               title: "InRange", transaction_date: 2.days.ago)
        create(:transaction, user: user, account: account, currency: currency,
               title: "Future",  transaction_date: Time.current)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns only transactions within the date range" do
        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("InRange")
        expect(titles).not_to include("Old", "Future")
      end
    end

    context "when filtered by search term matching title" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { search: "grocery" } }

      before do
        create(:transaction, user: user, account: account, currency: currency, title: "Weekly Grocery Run")
        create(:transaction, user: user, account: account, currency: currency, title: "Rent Payment")
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns transactions whose title matches case-insensitively" do
        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Weekly Grocery Run")
        expect(titles).not_to include("Rent Payment")
      end
    end

    context "when filtered by search term matching note" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { search: "monthly" } }

      before do
        create(:transaction, user: user, account: account, currency: currency,
               title: "Rent", note: "Monthly payment")
        create(:transaction, user: user, account: account, currency: currency,
               title: "Coffee", note: nil)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns transactions whose note matches case-insensitively" do
        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body)["transactions"].map { |t| t["title"] }
        expect(titles).to include("Rent")
        expect(titles).not_to include("Coffee")
      end
    end

    # FAILURE PATHS

    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when date_from is not a valid datetime" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { date_from: "not-a-date" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when date_to is not a valid datetime" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { date_to: "bad-date" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
