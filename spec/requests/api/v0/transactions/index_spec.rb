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
               split_method: :equal, owed_amount_cents: 500)
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
               split_method: :equal, owed_amount_cents: 300)
        create(:transaction_split, financial_transaction: shared_txn, user: other_user,
               split_method: :equal, owed_amount_cents: 300)
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

      it "returns only transactions for that account" do
        account_ids = JSON.parse(response.body)["transactions"].map { |t| t["account_id"] }.uniq
        expect(account_ids).to eq([ account.id ])
      end

      it "returns category information with each transaction" do
        transaction = JSON.parse(response.body)["transactions"].first

        expect(transaction["category_id"]).to eq(category.id)
        expect(transaction["category"]).to include(
          "id" => category.id,
          "name" => category.name,
          "category_type" => category.category_type,
          "user_id" => user.id
        )
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
        category_ids = JSON.parse(response.body)["transactions"].map { |t| t["category_id"] }.uniq
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
