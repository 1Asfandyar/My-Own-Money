# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Categories", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "GET /api/v0/categories" do
    let(:endpoint)        { "/api/v0/categories" }
    let(:query_params)    { {} }
    let(:request_headers) { headers }

    before { get endpoint, params: query_params, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated with include_zero_balance: true" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:query_params)    { { include_zero_balance: true } }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("categories/index_response")
      end

      it "returns the user's predefined categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].size).to eq(Categories::Defaults.all.size)
        expect(data["categories"].map { |c| c["user_id"] }.uniq).to eq([ user.id ])
      end

      it "returns balance_cents as 0 for new categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].map { |c| c["balance_cents"] }.uniq).to eq([ 0 ])
      end
    end

    context "when authenticated with default params (include_zero_balance: false)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("categories/index_response")
      end

      it "excludes categories with zero balance" do
        data = JSON.parse(response.body)
        expect(data["categories"]).to be_empty
      end
    end

    context "when authenticated with existing categories and non-zero balance" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user)      { create(:user) }
      let!(:own_category)   { create(:category, user: user) }
      let!(:other_category) { create(:category, user: other_user) }
      let(:account)         { create(:account, user: user, current_balance_cents: 10_000) }

      before do
        Transaction::Personal::Create.call(
          user:             user,
          transaction_type: :expense,
          title:            "Coffee",
          amount_cents:     500,
          account:          account,
          transaction_date: Time.current,
          category:         own_category
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns only the current user's non-zero balance categories" do
        data = JSON.parse(response.body)
        ids = data["categories"].map { |c| c["id"] }
        expect(ids).to include(own_category.id)
        expect(ids).not_to include(other_category.id)
        expect(data["categories"].map { |c| c["user_id"] }.uniq).to eq([ user.id ])
      end
    end

    context "when a personal expense transaction exists for a category" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:category)        { create(:category, user: user, category_type: :expense) }
      let(:account)         { create(:account, user: user, current_balance_cents: 10_000) }

      before do
        Transaction::Personal::Create.call(
          user:             user,
          transaction_type: :expense,
          title:            "Dinner",
          amount_cents:     3000,
          account:          account,
          transaction_date: Time.current,
          category:         category
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns the category with updated balance_cents" do
        data     = JSON.parse(response.body)
        cat_data = data["categories"].find { |c| c["id"] == category.id }
        expect(cat_data["balance_cents"]).to eq(3000)
      end
    end

    context "when a personal income transaction exists for a category" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:category)        { create(:category, user: user, category_type: :income) }
      let(:account)         { create(:account, user: user, current_balance_cents: 0) }

      before do
        Transaction::Personal::Create.call(
          user:             user,
          transaction_type: :income,
          title:            "Salary",
          amount_cents:     50_000,
          account:          account,
          transaction_date: Time.current,
          category:         category
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns the category with updated balance_cents" do
        data     = JSON.parse(response.body)
        cat_data = data["categories"].find { |c| c["id"] == category.id }
        expect(cat_data["balance_cents"]).to eq(50_000)
      end
    end

    context "when a personal transaction with category is updated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:category)        { create(:category, user: user, category_type: :expense) }
      let(:account)         { create(:account, user: user, current_balance_cents: 10_000) }

      before do
        result = Transaction::Personal::Create.call(
          user:             user,
          transaction_type: :expense,
          title:            "Groceries",
          amount_cents:     2000,
          account:          account,
          transaction_date: Time.current,
          category:         category
        )
        txn = result.value!
        Transaction::Personal::Update.call(transaction: txn, amount_cents: 4000)
        get endpoint, params: query_params, headers: request_headers
      end

      it "reflects the updated amount in balance_cents" do
        data     = JSON.parse(response.body)
        cat_data = data["categories"].find { |c| c["id"] == category.id }
        expect(cat_data["balance_cents"]).to eq(4000)
      end
    end

    context "when a personal transaction with category is destroyed" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:query_params)    { { include_zero_balance: true } }
      let(:category)        { create(:category, user: user, category_type: :expense) }
      let(:account)         { create(:account, user: user, current_balance_cents: 10_000) }

      before do
        result = Transaction::Personal::Create.call(
          user:             user,
          transaction_type: :expense,
          title:            "Transport",
          amount_cents:     1500,
          account:          account,
          transaction_date: Time.current,
          category:         category
        )
        txn = result.value!
        Transaction::Personal::Destroy.call(transaction: txn)
        get endpoint, params: query_params, headers: request_headers
      end

      it "reverts balance_cents back to 0" do
        data     = JSON.parse(response.body)
        cat_data = data["categories"].find { |c| c["id"] == category.id }
        expect(cat_data["balance_cents"]).to eq(0)
      end
    end

    # FILTER PATHS
    context "when filtering by category_type: expense" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:account)         { create(:account, user: user, current_balance_cents: 20_000) }
      let!(:expense_cat)    { create(:category, user: user, category_type: :expense) }
      let!(:income_cat)     { create(:category, user: user, category_type: :income) }
      let(:query_params)    { { category_type: "expense" } }

      before do
        Transaction::Personal::Create.call(
          user: user, transaction_type: :expense, title: "Food",
          amount_cents: 1000, account: account, transaction_date: Time.current,
          category: expense_cat
        )
        Transaction::Personal::Create.call(
          user: user, transaction_type: :income, title: "Pay",
          amount_cents: 5000, account: account, transaction_date: Time.current,
          category: income_cat
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns only expense categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].map { |c| c["category_type"] }.uniq).to eq([ "expense" ])
        expect(data["categories"].map { |c| c["id"] }).to include(expense_cat.id)
        expect(data["categories"].map { |c| c["id"] }).not_to include(income_cat.id)
      end
    end

    context "when filtering by category_type: income" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:account)         { create(:account, user: user, current_balance_cents: 20_000) }
      let!(:expense_cat)    { create(:category, user: user, category_type: :expense) }
      let!(:income_cat)     { create(:category, user: user, category_type: :income) }
      let(:query_params)    { { category_type: "income" } }

      before do
        Transaction::Personal::Create.call(
          user: user, transaction_type: :expense, title: "Food",
          amount_cents: 1000, account: account, transaction_date: Time.current,
          category: expense_cat
        )
        Transaction::Personal::Create.call(
          user: user, transaction_type: :income, title: "Pay",
          amount_cents: 5000, account: account, transaction_date: Time.current,
          category: income_cat
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns only income categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].map { |c| c["category_type"] }.uniq).to eq([ "income" ])
        expect(data["categories"].map { |c| c["id"] }).to include(income_cat.id)
        expect(data["categories"].map { |c| c["id"] }).not_to include(expense_cat.id)
      end
    end

    context "when filtering by name (partial, case-insensitive)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:account)         { create(:account, user: user, current_balance_cents: 20_000) }
      let!(:matching_cat)   { create(:category, user: user, name: "Groceries", category_type: :expense) }
      let!(:other_cat)      { create(:category, user: user, name: "Transport", category_type: :expense) }
      let(:query_params)    { { name: "groc" } }

      before do
        Transaction::Personal::Create.call(
          user: user, transaction_type: :expense, title: "Food",
          amount_cents: 500, account: account, transaction_date: Time.current,
          category: matching_cat
        )
        Transaction::Personal::Create.call(
          user: user, transaction_type: :expense, title: "Bus",
          amount_cents: 200, account: account, transaction_date: Time.current,
          category: other_cat
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns only categories whose name matches" do
        data = JSON.parse(response.body)
        ids  = data["categories"].map { |c| c["id"] }
        expect(ids).to include(matching_cat.id)
        expect(ids).not_to include(other_cat.id)
      end
    end

    context "when combining category_type and name filters" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:account)         { create(:account, user: user, current_balance_cents: 20_000) }
      let!(:match_cat)      { create(:category, user: user, name: "Food & Dining", category_type: :expense) }
      let!(:wrong_type_cat) { create(:category, user: user, name: "Food Salary",   category_type: :income) }
      let!(:no_match_cat)   { create(:category, user: user, name: "Transport",     category_type: :expense) }
      let(:query_params)    { { category_type: "expense", name: "food" } }

      before do
        [ match_cat, no_match_cat ].each do |cat|
          Transaction::Personal::Create.call(
            user: user, transaction_type: :expense, title: "X",
            amount_cents: 100, account: account, transaction_date: Time.current,
            category: cat
          )
        end
        Transaction::Personal::Create.call(
          user: user, transaction_type: :income, title: "Y",
          amount_cents: 100, account: account, transaction_date: Time.current,
          category: wrong_type_cat
        )
        get endpoint, params: query_params, headers: request_headers
      end

      it "returns only categories matching both filters" do
        data = JSON.parse(response.body)
        ids  = data["categories"].map { |c| c["id"] }
        expect(ids).to eq([ match_cat.id ])
      end
    end

    context "when combining include_zero_balance: true with category_type" do
      let(:request_headers)   { headers.merge(auth_headers(user)) }
      let!(:expense_zero_cat) { create(:category, user: user, category_type: :expense) }
      let!(:income_zero_cat)  { create(:category, user: user, category_type: :income) }

      before { get endpoint, params: { include_zero_balance: true, category_type: "expense" }, headers: request_headers }

      it "returns all expense categories including zero-balance ones" do
        data = JSON.parse(response.body)
        ids  = data["categories"].map { |c| c["id"] }
        expect(ids).to include(expense_zero_cat.id)
        expect(ids).not_to include(income_zero_cat.id)
        expect(data["categories"].map { |c| c["category_type"] }.uniq).to eq([ "expense" ])
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category_type param is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:query_params)    { { category_type: "invalid" } }

      it "returns 422" do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
