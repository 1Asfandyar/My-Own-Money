# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Dashboard", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user) { create(:user) }

  describe "GET /api/v0/dashboard" do
    let(:endpoint)        { "/api/v0/dashboard" }
    let(:request_headers) { headers }

    # SUCCESS PATHS
    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      let!(:account) { create(:account, user: user, current_balance_cents: 12_000) }
      let!(:category_zero) { create(:category, user: user, category_type: :expense, balance_cents: 0) }
      let!(:category_non_zero) { create(:category, user: user, category_type: :income, balance_cents: 3_500) }

      let(:friend_accepted) { create(:user) }
      let(:friend_pending) { create(:user) }

      let!(:accepted_friendship) { create(:friendship, :accepted, sender: user, receiver: friend_accepted) }
      let!(:pending_friendship) { create(:friendship, sender: user, receiver: friend_pending) }

      let!(:debt_to_receive) { create(:debt, from_user: friend_accepted, to_user: user, amount_cents: 1_700) }
      let!(:debt_to_pay) { create(:debt, from_user: user, to_user: friend_pending, amount_cents: 900) }

      let!(:income_current_month) do
        create(
          :transaction,
          user: user,
          account: account,
          transaction_type: :income,
          visibility_type: :personal,
          amount_cents: 5_000,
          transaction_date: Date.current.beginning_of_month + 2.days
        )
      end

      let!(:expense_current_month) do
        create(
          :transaction,
          user: user,
          account: account,
          transaction_type: :expense,
          visibility_type: :personal,
          amount_cents: 1_250,
          transaction_date: Date.current.beginning_of_month + 3.days
        )
      end

      let!(:shared_expense_txn) do
        create(
          :transaction,
          user: friend_accepted,
          account: create(:account, user: friend_accepted),
          transaction_type: :expense,
          visibility_type: :shared,
          amount_cents: 2_000,
          transaction_date: Date.current.beginning_of_month + 4.days
        )
      end

      let!(:shared_split_for_user) do
        create(
          :transaction_split,
          financial_transaction: shared_expense_txn,
          user: user,
          owed_amount_cents: 750
        )
      end

      let!(:income_previous_month) do
        create(
          :transaction,
          user: user,
          account: account,
          transaction_type: :income,
          visibility_type: :personal,
          amount_cents: 9_999,
          transaction_date: (Date.current.beginning_of_month - 1.day)
        )
      end

      before do
        get endpoint, headers: request_headers
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("dashboard/show_response")
      end

      it "returns current-month totals and overall debt totals" do
        data = JSON.parse(response.body)

        expect(data.dig("summary", "total_income")).to eq(5_000)
        expect(data.dig("summary", "total_expense")).to eq(2_000)
        expect(data.dig("summary", "total_owed_to_you_cents")).to eq(1_700)
        expect(data.dig("summary", "total_you_owe_cents")).to eq(900)
      end

      it "returns accepted friendships and excludes zero-balance categories" do
        data = JSON.parse(response.body)

        friendship_ids = data.fetch("friendships").map { |f| f.fetch("id") }
        expect(friendship_ids).to include(accepted_friendship.id)
        expect(friendship_ids).not_to include(pending_friendship.id)

        category_ids = data.fetch("categories").map { |c| c.fetch("id") }
        expect(category_ids).to include(category_non_zero.id)
        expect(category_ids).not_to include(category_zero.id)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      before do
        get endpoint, headers: request_headers
      end

      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
