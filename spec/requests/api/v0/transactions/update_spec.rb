# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Transactions", type: :request do
  let(:headers)      { { "Content-Type" => "application/json" } }
  let(:user)         { create(:user) }
  let(:currency)     { create(:currency) }
  let(:account)      { create(:account, user: user, currency: currency) }
  let(:to_account)   { create(:account, user: user, currency: currency) }
  let(:category)     { create(:category, user: user) }
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

  describe "PATCH /api/v0/transactions/:id" do
    let(:endpoint)        { "/api/v0/transactions/#{transaction.id}" }
    let(:request_headers) { headers }
    let(:request_params)  { { title: "Updated Title" } }

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
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
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { amount_cents: 9999 } }

      it "returns 200 and updates balance" do
        expect(response).to have_http_status(:ok)
        # account started at 0: revert expense (+5000) then apply new expense (-9999) → -4999
        expect(account.reload.current_balance_cents).to eq(-4999)
      end
    end

    context "when changing transaction_type from expense to income" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { transaction_type: "income" } }

      it "returns 200 and reverses balance correctly" do
        expect(response).to have_http_status(:ok)
        # account started at 0: revert expense (+5000) then apply income (+5000) → +10000
        expect(account.reload.current_balance_cents).to eq(10000)
      end
    end

    context "when updating account_id" do
      let(:other_account)   { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { account_id: other_account.id } }

      it "returns 200 and moves balance between accounts" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.account_id).to eq(other_account.id)
        # original account (started at 0): expense reverted → +5000
        expect(account.reload.current_balance_cents).to eq(5000)
        # new account (started at 0): expense applied → -5000
        expect(other_account.reload.current_balance_cents).to eq(-5000)
      end
    end

    context "when updating note" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { note: "New note" } }

      it "returns 200 and persists note" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.note).to eq("New note")
      end
    end

    context "when updating category_id" do
      let(:new_category)    { create(:category, user: user) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_id: new_category.id } }

      it "returns 200 and updates category" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.category_id).to eq(new_category.id)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/transactions/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction belongs to a different user" do
      let(:other_user)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(other_user)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
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

    context "when category_id references a default category assigned to the current user" do
      let(:default_category) { user.categories.find_by!(name: "Groceries") }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { category_id: default_category.id } }

      it "returns 200 and updates the category" do
        expect(response).to have_http_status(:ok)
        expect(transaction.reload.category_id).to eq(default_category.id)
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

    context "when transaction_date is invalid" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:request_params)   { { transaction_date: "not-a-date" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction_type is invalid" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:request_params)   { { transaction_type: "invalid_type" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when updating a transfer transaction amount" do
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { amount_cents: 5000 } }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/update_response")
      end

      it "reverts old balance and applies new transfer amount" do
        # account started at -2000 (from setup), revert (+2000) then apply (-5000) → -5000
        expect(account.reload.current_balance_cents).to eq(-5000)
        # to_account started at +2000, revert (-2000) then apply (+5000) → +5000
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
        # original account (was -2000): transfer reverted → 0
        expect(account.reload.current_balance_cents).to eq(0)
        # new from_account: transfer applied → -2000
        expect(new_from_account.reload.current_balance_cents).to eq(-2000)
        # to_account: unchanged net (reverted +2000 then re-applied +2000)
        expect(to_account.reload.current_balance_cents).to eq(2000)
      end
    end

    context "when from_account_id and to_account_id are the same on update" do
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { from_account_id: account.id, to_account_id: account.id } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when from_account_id does not belong to the current user on update" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { from_account_id: other_account.id } }

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
