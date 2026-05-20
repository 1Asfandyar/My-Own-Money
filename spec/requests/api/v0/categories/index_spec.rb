# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Categories", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "GET /api/v0/categories" do
    let(:endpoint)        { "/api/v0/categories" }
    let(:request_headers) { headers }

    before { get endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("categories/index_response")
      end

      it "returns the user's predefined categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].size).to eq(Categories::Defaults.all.size)
        expect(data["categories"].map { |category| category["user_id"] }.uniq).to eq([ user.id ])
      end

      it "returns balance_cents as 0 for new categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].map { |c| c["balance_cents"] }.uniq).to eq([ 0 ])
      end
    end

    context "when authenticated with existing categories" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:other_user)      { create(:user) }
      let!(:own_categories)  { create_list(:category, 2, user: user) }
      let!(:other_category)  { create(:category, user: other_user) }

      before { get endpoint, headers: request_headers }

      it "returns only the current user's categories" do
        data = JSON.parse(response.body)
        expect(data["categories"].size).to eq(Categories::Defaults.all.size + 2)
        expect(data["categories"].map { |c| c["id"] }).to include(*own_categories.map(&:id))
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
        get endpoint, headers: request_headers
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
        get endpoint, headers: request_headers
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
        get endpoint, headers: request_headers
      end

      it "reflects the updated amount in balance_cents" do
        data     = JSON.parse(response.body)
        cat_data = data["categories"].find { |c| c["id"] == category.id }
        expect(cat_data["balance_cents"]).to eq(4000)
      end
    end

    context "when a personal transaction with category is destroyed" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
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
        get endpoint, headers: request_headers
      end

      it "reverts balance_cents back to 0" do
        data     = JSON.parse(response.body)
        cat_data = data["categories"].find { |c| c["id"] == category.id }
        expect(cat_data["balance_cents"]).to eq(0)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
