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
    let(:request_params)  { { type: "none" } }

    before do
      get endpoint, params: request_params, headers: request_headers
    end

    # SUCCESS PATHS

    context "when authenticated with no filters" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      before do
        other_user = create(:user)
        create(:transaction, user: user, account: account, currency: currency, category: category,
               title: "Groceries", transaction_date: 2.days.ago)
        create(:transaction, user: user, account: account, currency: currency, category: category,
               title: "Rent", transaction_date: 1.day.ago)
        create(:transaction, user: other_user,
               account: create(:account, user: other_user, currency: currency),
               currency: currency)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/index_response")
      end

      it "returns only the current user's transactions" do
        ids = JSON.parse(response.body)["transactions"].map { |t| t["user_id"] }.uniq
        expect(ids).to eq([ user.id ])
      end
    end

    context "when filtered by account_id" do
      let(:other_account)  { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "none", account_id: account.id } }

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
    end

    context "when filtered by account_id with type personal" do
      let(:income_category) { create(:category, user: user, category_type: :income) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "personal", account_id: account.id } }

      before do
        account.update!(current_balance_cents: 60_000)
        create(:transaction, user: user, account: account, currency: currency, category: category,
               transaction_type: :expense, amount_cents: 2_000)
        create(:transaction, user: user, account: account, currency: currency, category: income_category,
               transaction_type: :income, amount_cents: 5_000)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns metadata for the filtered transactions" do
        body = JSON.parse(response.body)
        expect(body["total_amount_cents"]).to eq(3_000)
        expect(body["total_absolute_amount_cents"]).to eq(7_000)
        expect(body["total_account_balance_cents"]).to eq(60_000)
        expect(body["total_spent_cents"]).to eq(2_000)
        expect(body["total_income_cents"]).to eq(5_000)
      end
    end

    context "when grouped by category" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:income_category)  { create(:category, user: user, name: "Salary", category_type: :income) }
      let(:expense_category) { create(:category, user: user, name: "Food", category_type: :expense) }
      let(:rent_category)    { create(:category, user: user, name: "Rent", category_type: :expense) }
      let(:request_params)   { { type: "personal", account_id: account.id } }

      before do
        account.update!(current_balance_cents: 60_000)
        create(:transaction, user: user, account: account, currency: currency, category: expense_category,
               title: "Lunch", transaction_type: :expense, amount_cents: 2_000)
        create(:transaction, user: user, account: account, currency: currency, category: expense_category,
               title: "Dinner", transaction_type: :expense, amount_cents: 3_000)
        create(:transaction, user: user, account: account, currency: currency, category: rent_category,
               title: "Rent", transaction_type: :expense, amount_cents: 5_000)
        create(:transaction, user: user, account: account, currency: currency, category: income_category,
               title: "Salary", transaction_type: :income, amount_cents: 10_000)
        create(:transaction, :transfer, user: user, account: account, currency: currency, category: nil,
               title: "Transfer", amount_cents: 4_000)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns category totals with nested transactions" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/by_category_response")

        body = JSON.parse(response.body)
        food = body["categories"].find { |summary| summary.dig("category", "id") == expense_category.id }
        salary = body["categories"].find { |summary| summary.dig("category", "id") == income_category.id }

        expect(body["total_amount_cents"]).to eq(0)
        expect(body["total_absolute_amount_cents"]).to eq(20_000)
        expect(body["total_account_balance_cents"]).to eq(60_000)
        expect(body["total_spent_cents"]).to eq(10_000)
        expect(body["total_income_cents"]).to eq(10_000)
        expect(food["amount_cents"]).to eq(-5_000)
        expect(food["percentage"]).to eq(8.33)
        expect(food["transactions"].map { |transaction| transaction["title"] })
          .to contain_exactly("Lunch", "Dinner")
        expect(salary["amount_cents"]).to eq(10_000)
        expect(salary["percentage"]).to eq(16.67)
      end
    end

    context "when grouped by category and filtered by account_id" do
      let(:other_account)    { create(:account, user: user, currency: currency) }
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:expense_category) { create(:category, user: user, category_type: :expense) }
      let(:request_params)   { { type: "personal", account_id: account.id } }

      before do
        account.update!(current_balance_cents: 60_000)
        other_account.update!(current_balance_cents: 40_000)
        create(:transaction, user: user, account: account, currency: currency, category: expense_category,
               transaction_type: :expense, amount_cents: 2_000)
        create(:transaction, user: user, account: other_account, currency: currency, category: expense_category,
               transaction_type: :expense, amount_cents: 3_000)
        get endpoint, params: request_params, headers: request_headers
      end

      it "groups only transactions from that account" do
        transactions = JSON.parse(response.body)["categories"].flat_map { |summary| summary["transactions"] }
        account_ids = transactions.map { |transaction| transaction["account_id"] }.uniq
        expect(account_ids).to eq([ account.id ])
      end

      it "calculates percentage from that account balance" do
        body = JSON.parse(response.body)
        category = body["categories"].first
        expect(body["total_account_balance_cents"]).to eq(60_000)
        expect(category["amount_cents"]).to eq(-2_000)
        expect(category["percentage"]).to eq(3.33)
      end
    end

    context "when grouped by friends" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "shared" } }
      let(:friend_one)      { create(:user, full_name: "Friend One") }
      let(:friend_two)      { create(:user, full_name: "Friend Two") }
      let(:friend_account)  { create(:account, user: friend_one, currency: currency) }
      let(:friend_category) { create(:category, user: friend_one) }

      before do
        paid_by_user = create(:transaction, :shared, user: user, account: account, currency: currency, category: category,
                              title: "Dinner", amount_cents: 3_000)
        paid_by_user.transaction_splits.create!(user: user, split_method: :equal, owed_amount_cents: 1_000)
        paid_by_user.transaction_splits.create!(user: friend_one, split_method: :equal, owed_amount_cents: 1_000)
        paid_by_user.transaction_splits.create!(user: friend_two, split_method: :equal, owed_amount_cents: 1_000)

        paid_by_friend = create(:transaction, :shared, user: friend_one, account: friend_account, currency: currency,
                                category: friend_category, title: "Taxi", amount_cents: 2_000)
        paid_by_friend.transaction_splits.create!(user: user, split_method: :equal, owed_amount_cents: 1_000)
        paid_by_friend.transaction_splits.create!(user: friend_one, split_method: :equal, owed_amount_cents: 1_000)

        create(:transaction, user: user, account: account, currency: currency, category: category, title: "Personal")
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns friends with their shared transactions" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/by_friends_response")
      end

      it "groups shared transactions involving the current user by friend" do
        friends = JSON.parse(response.body)["friends"]
        friend_one_summary = friends.find { |summary| summary.dig("friend", "id") == friend_one.id }
        friend_two_summary = friends.find { |summary| summary.dig("friend", "id") == friend_two.id }

        expect(friend_one_summary["transactions"].map { |transaction| transaction["title"] })
          .to contain_exactly("Dinner", "Taxi")
        expect(friend_two_summary["transactions"].map { |transaction| transaction["title"] })
          .to contain_exactly("Dinner")
        expect(friends.flat_map { |summary| summary["transactions"] }.map { |transaction| transaction["title"] })
          .not_to include("Personal")
      end
    end

    context "when filtered by category_id" do
      let(:other_category)  { create(:category, user: user) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "none", category_id: category.id } }

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
      let(:request_params)  { { type: "none", date_from: 3.days.ago.iso8601, date_to: 1.day.ago.iso8601 } }

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
      let(:request_params)  { { type: "none", search: "grocery" } }

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
      let(:request_params)  { { type: "none", search: "monthly" } }

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

    context "when type is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "bad_type" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when type is personal but account_id is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "personal" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when date_from is not a valid datetime" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "none", date_from: "not-a-date" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when date_to is not a valid datetime" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { type: "none", date_to: "bad-date" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
