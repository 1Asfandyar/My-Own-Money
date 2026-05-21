# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Categories::Summary", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "GET /api/v0/categories/summary" do
    let(:endpoint)        { "/api/v0/categories/summary" }
    let(:request_headers) { headers }
    let(:request_params)  { { account_id: account.id } }
    let(:currency)        { create(:currency) }
    let(:account)         { create(:account, user: user, currency: currency, current_balance_cents: 60_000) }

    before do
      get endpoint, params: request_params, headers: request_headers
    end

    context "when authenticated" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:other_account)    { create(:account, user: user, currency: currency, current_balance_cents: 40_000) }
      let(:income_category)  { create(:category, user: user, name: "Salary", category_type: :income) }
      let(:expense_category) { create(:category, user: user, name: "Food", category_type: :expense) }
      let(:rent_category)    { create(:category, user: user, name: "Rent", category_type: :expense) }

      before do
        create(:transaction, user: user, account: account, currency: currency, category: expense_category,
               title: "Lunch", transaction_type: :expense, amount_cents: 2_000)
        create(:transaction, user: user, account: account, currency: currency, category: expense_category,
               title: "Dinner", transaction_type: :expense, amount_cents: 3_000)
        create(:transaction, user: user, account: account, currency: currency, category: rent_category,
               title: "Rent", transaction_type: :expense, amount_cents: 5_000)
        create(:transaction, user: user, account: account, currency: currency, category: income_category,
               title: "Salary", transaction_type: :income, amount_cents: 10_000)
        create(:transaction, user: user, account: other_account, currency: currency, category: expense_category,
               title: "Other account lunch", transaction_type: :expense, amount_cents: 7_000)
        create(:transaction, :transfer, user: user, account: account, currency: currency, category: nil,
               title: "Transfer", amount_cents: 4_000)
        get endpoint, params: request_params, headers: request_headers
      end

      it "returns category totals with nested transactions" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("categories/summary_response")

        body = JSON.parse(response.body)
        food = body["categories"].find { |summary| summary.dig("category", "id") == expense_category.id }
        salary = body["categories"].find { |summary| summary.dig("category", "id") == income_category.id }
        transactions = body["categories"].flat_map { |summary| summary["transactions"] }

        expect(body).not_to include(
          "total_amount_cents",
          "total_absolute_amount_cents",
          "total_account_balance_cents",
          "total_spent_cents",
          "total_income_cents"
        )
        expect(food["amount_cents"]).to eq(-5_000)
        expect(food["percentage"]).to eq(8.33)
        expect(food.dig("category", "balance_cents")).to eq(5_000)
        expect(food["transactions"].map { |transaction| transaction["title"] })
          .to contain_exactly("Lunch", "Dinner")
        expect(salary["amount_cents"]).to eq(10_000)
        expect(salary["percentage"]).to eq(16.67)
        expect(salary.dig("category", "balance_cents")).to eq(10_000)
        expect(transactions.map { |transaction| transaction["account_id"] }.uniq).to eq([ account.id ])
        expect(transactions.map { |transaction| transaction["title"] }).not_to include("Other account lunch", "Transfer")
      end
    end

    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when account_id is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { {} }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
