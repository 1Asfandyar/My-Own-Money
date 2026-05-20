# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Transactions", type: :request do
  let(:headers)    { { "Content-Type" => "application/json" } }
  let(:user)       { create(:user) }
  let(:currency)   { create(:currency) }
  let(:account)    { create(:account, user: user, currency: currency) }
  let(:to_account) { create(:account, user: user, currency: currency) }
  let(:category)   { create(:category, user: user) }

  let!(:transaction) do
    create(:transaction,
           user:             user,
           account:          account,
           category:         category,
           currency:         currency,
           transaction_type: :expense,
           visibility_type:  :personal,
           amount_cents:     5000,
           title:            "Groceries",
           transaction_date: Time.current)
  end

  let(:transfer_transaction) do
    create(:transaction, :transfer,
           user:             user,
           account:          account,
           transfer_account: to_account,
           currency:         currency,
           amount_cents:     2000,
           title:            "Wallet top-up",
           transaction_date: Time.current).tap do
      account.update!(current_balance_cents: account.current_balance_cents - 2000)
      to_account.update!(current_balance_cents: to_account.current_balance_cents + 2000)
    end
  end

  # Shared-expense fixture: user paid 3000 split equally with user2 + user3.
  # account balance set to -3000 to reflect that the payment was applied.
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:shared_transaction) do
    t = create(:transaction,
               user:             user,
               account:          account,
               category:         category,
               currency:         currency,
               transaction_type: :expense,
               visibility_type:  :shared,
               amount_cents:     3000,
               title:            "Shared Dinner",
               transaction_date: Time.current)
    t.transaction_splits.create!(user_id: user.id,  split_method: :equal, owed_amount_cents: 1000)
    t.transaction_splits.create!(user_id: user2.id, split_method: :equal, owed_amount_cents: 1000)
    t.transaction_splits.create!(user_id: user3.id, split_method: :equal, owed_amount_cents: 1000)
    create(:debt, from_user: user2, to_user: user, amount_cents: 1000)
    create(:debt, from_user: user3, to_user: user, amount_cents: 1000)
    account.update!(current_balance_cents: -3000)
    t
  end

  describe "PATCH /api/v0/transactions/:id" do
    let(:endpoint)        { "/api/v0/transactions/#{transaction.id}" }
    let(:request_headers) { headers }
    let(:request_params)  { { title: "Updated Title" } }

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    # ─────────────────────────────────────────────────────────────────────────
    # SUCCESS PATHS
    # ─────────────────────────────────────────────────────────────────────────

    context "when authenticated and updating the title" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/update_response")
      end

      it "persists the updated title" do
        expect(transaction.reload.title).to eq("Updated Title")
      end
    end

    context "when updating amount_cents" do
      let(:category)        { create(:category, user: user, balance_cents: 5000) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { amount_cents: 9999 } }

      it "returns 200 and adjusts the account balance" do
        expect(response).to have_http_status(:ok)
        # account started at 0: revert expense (+5000) then apply new expense (-9999) → -4999
        expect(account.reload.current_balance_cents).to eq(-4999)
      end

      it "adjusts category balance_cents to the new amount" do
        # revert old 5000, apply new 9999 → 9999
        expect(category.reload.balance_cents).to eq(9999)
      end
    end

    context "when changing transaction_type from expense to income" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { transaction_type: "income" } }

      it "returns 200 and reverses balance correctly" do
        expect(response).to have_http_status(:ok)
        # account started at 0: revert expense (+5000) then apply income (+5000) → +10000
        expect(account.reload.current_balance_cents).to eq(10_000)
      end
    end

    context "when updating account_id" do
      let(:other_account)   { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { account_id: other_account.id } }

      it "returns 200 and moves the balance between accounts" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.account_id).to eq(other_account.id)
        # original account reverted → +5000; new account charged → -5000
        expect(account.reload.current_balance_cents).to eq(5000)
        expect(other_account.reload.current_balance_cents).to eq(-5000)
      end
    end

    context "when updating note" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { note: "New note" } }

      it "returns 200 and persists the note" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.note).to eq("New note")
      end
    end

    context "when updating category_id" do
      let(:category)        { create(:category, user: user, balance_cents: 5000) }
      let(:new_category)    { create(:category, user: user) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_id: new_category.id } }

      it "returns 200 and updates the category" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.category_id).to eq(new_category.id)
      end

      it "moves balance_cents from old category to new category" do
        # old category: 5000 - 5000 = 0; new category: 0 + 5000 = 5000
        expect(category.reload.balance_cents).to eq(0)
        expect(new_category.reload.balance_cents).to eq(5000)
      end
    end

    context "when updating transaction_date" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { transaction_date: "2025-01-15T08:30:00Z" } }

      it "returns 200 and persists the new date" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.transaction_date.utc.strftime("%Y-%m-%d")).to eq("2025-01-15")
      end
    end

    context "when updating currency_id" do
      let(:new_currency)    { create(:currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { currency_id: new_currency.id } }

      it "returns 200 and persists the new currency" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.currency_id).to eq(new_currency.id)
      end
    end

    context "when category_id references a default category assigned to the current user" do
      let(:default_category) { user.categories.find_by!(name: "Groceries") }
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:request_params)   { { category_id: default_category.id } }

      it "returns 200 and updates the category" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.category_id).to eq(default_category.id)
      end
    end

    # ── Transfer transaction ──────────────────────────────────────────────────

    context "when updating a transfer transaction's amount" do
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { amount_cents: 5000 } }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/update_response")
      end

      it "reverts old balance and applies the new transfer amount" do
        # account was -2000; revert (+2000 → 0) then apply (-5000 → -5000)
        expect(account.reload.current_balance_cents).to eq(-5000)
        # to_account was +2000; revert (-2000 → 0) then apply (+5000 → +5000)
        expect(to_account.reload.current_balance_cents).to eq(5000)
      end
    end

    context "when updating a transfer transaction's from_account" do
      let(:new_from_account) { create(:account, user: user, currency: currency) }
      let(:endpoint)         { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:request_params)   { { from_account_id: new_from_account.id } }

      it "returns 200 and moves the debit to the new from_account" do
        expect(response).to have_http_status(:ok)
        # original account reverted: -2000 + 2000 = 0
        expect(account.reload.current_balance_cents).to eq(0)
        # new from_account charged: -2000
        expect(new_from_account.reload.current_balance_cents).to eq(-2000)
        # to_account re-credited (reverted -2000 + re-applied +2000) = net unchanged
        expect(to_account.reload.current_balance_cents).to eq(2000)
      end
    end

    context "when updating a transfer transaction's to_account" do
      let(:new_to_account)  { create(:account, user: user, currency: currency) }
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { to_account_id: new_to_account.id } }

      it "returns 200 and redirects the credit to the new to_account" do
        expect(response).to have_http_status(:ok)
        # account re-debited (reverted +2000 + re-applied -2000) = net unchanged at -2000
        expect(account.reload.current_balance_cents).to eq(-2000)
        # old to_account reverted: +2000 - 2000 = 0
        expect(to_account.reload.current_balance_cents).to eq(0)
        # new to_account credited: +2000
        expect(new_to_account.reload.current_balance_cents).to eq(2000)
      end
    end

    context "when converting a personal expense to a transfer" do
      let(:new_to_account)  { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        { transaction_type: "transfer", to_account_id: new_to_account.id }
      end

      it "returns 200 and changes the transaction type" do
        expect(response).to have_http_status(:ok)
        t = transaction.reload
        expect(t.transaction_type).to eq("transfer")
        expect(t.transfer_account_id).to eq(new_to_account.id)
      end

      it "reverts the expense and applies the transfer balance" do
        # account at 0: revert expense (+5000 → 5000) then debit transfer (-5000 → 0)
        expect(account.reload.current_balance_cents).to eq(0)
        # new to_account credited: +5000
        expect(new_to_account.reload.current_balance_cents).to eq(5000)
      end
    end

    # ── Shared expense updates ────────────────────────────────────────────────

    context "when updating a shared expense's amount (no participant change)" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { amount_cents: 6000 } }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/update_response")
      end

      it "recalculates equal-split debts for the new amount" do
        # Old 1000 debts reversed to 0; new 2000 debts applied (6000 / 3 users)
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(2000)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(2000)
      end

      it "adjusts the account balance for the new amount" do
        # revert old (−3000 → 0) then apply new (0 − 6000 → −6000)
        expect(account.reload.current_balance_cents).to eq(-6000)
      end
    end

    context "when updating shared_by participants on an equal-split shared expense" do
      let(:user4) { create(:user) }
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { shared_by: [ user.id, user4.id ], split_method: "equal" } }

      it "returns 200 and replaces splits with the new participants" do
        expect(response).to have_http_status(:ok)
        t = shared_transaction.reload
        expect(t.transaction_splits.pluck(:user_id)).to contain_exactly(user.id, user4.id)
        expect(t.transaction_splits.sum(:owed_amount_cents)).to eq(3000)
      end

      it "reverses old debts and applies new debts" do
        # user2 and user3 old debts (1000) reversed → amount 0
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(0)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(0)
        # user4 now owes user 1500 (3000 / 2)
        expect(Debt.find_by(from_user_id: user4.id, to_user_id: user.id)&.amount_cents).to eq(1500)
      end
    end

    context "when changing split method from equal to exact with user_shares" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          split_method: "exact",
          user_shares:  [
            { user_id: user.id,  share: 1500 },
            { user_id: user2.id, share: 1500 }
          ]
        }
      end

      it "returns 200 and updates splits to the exact amounts" do
        expect(response).to have_http_status(:ok)
        splits = shared_transaction.reload.transaction_splits.index_by(&:user_id)
        expect(splits[user.id].owed_amount_cents).to eq(1500)
        expect(splits[user2.id].owed_amount_cents).to eq(1500)
        expect(splits.values.map(&:split_method).uniq).to eq([ "exact" ])
      end

      it "reverses old debts and applies new exact debts" do
        # user2: old 1000 reversed then 1500 applied → 1500
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(1500)
        # user3: old 1000 reversed, no new debt → 0
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(0)
      end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # FAILURE PATHS
    # ─────────────────────────────────────────────────────────────────────────

    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the transaction does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/transactions/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the transaction belongs to a different user" do
      let(:other_user)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(other_user)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when amount_cents is zero" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { amount_cents: 0 } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction_date is an invalid value" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { transaction_date: "not-a-date" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction_type is an invalid value" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { transaction_type: "invalid_type" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when account_id does not belong to the current user" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { account_id: other_account.id } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category_id does not belong to the current user" do
      let(:other_category)  { create(:category) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_id: other_category.id } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when currency_id does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { currency_id: 999_999 } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    # ── Transfer failure paths ────────────────────────────────────────────────

    context "when from_account_id and to_account_id are the same" do
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { from_account_id: account.id, to_account_id: account.id } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when from_account_id does not belong to the current user" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { from_account_id: other_account.id } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when to_account_id does not belong to the current user" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { to_account_id: other_account.id } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    # ── Shared expense failure paths ──────────────────────────────────────────

    context "when changing to a non-equal split method without providing user_shares" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { split_method: "exact" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when paid_by user does not exist on a shared expense" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { paid_by: 999_999 } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when account_id does not belong to the effective payer on a shared expense" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { account_id: other_account.id } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when category_id does not belong to the effective payer on a shared expense" do
      let(:other_category)  { create(:category) }
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_id: other_category.id } }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when shared_by contains an unknown user ID" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { shared_by: [ user.id, 999_999 ], split_method: "equal" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when user_shares contains an unknown user ID" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          split_method: "exact",
          user_shares:  [
            { user_id: user.id, share: 1500 },
            { user_id: 999_999, share: 1500 }
          ]
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when exact split shares do not sum to the transaction amount" do
      let(:endpoint)        { "/api/v0/transactions/#{shared_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          split_method: "exact",
          user_shares:  [
            { user_id: user.id,  share: 500 },
            { user_id: user2.id, share: 500 }
          ]
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
