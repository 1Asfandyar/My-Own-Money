# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Transactions", type: :request do
  let(:headers)   { { "Content-Type" => "application/json" } }
  let(:user)      { create(:user) }
  let(:currency)  { create(:currency) }
  let(:account)   { create(:account, user: user, currency: currency) }
  let(:category)  { create(:category, user: user) }

  describe "POST /api/v0/transactions" do
    let(:endpoint)        { "/api/v0/transactions" }
    let(:request_headers) { headers }
    let(:title)           { "Groceries" }
    let(:amount_cents)    { 5000 }
    let(:transaction_type) { "expense" }
    let(:transaction_date) { "2026-05-12T10:00:00Z" }

    let(:request_params) do
      {
        title:            title,
        amount_cents:     amount_cents,
        transaction_type: transaction_type,
        account_id:       account.id,
        category_id:      category.id,
        transaction_date: transaction_date
      }
    end

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with a personal expense" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as personal" do
        t = Transaction.find_by(title: title, user_id: user.id)
        expect(t).to be_present
        expect(t.visibility_type).to eq("personal")
        expect(t.transaction_type).to eq("expense")
      end
    end

    context "when authenticated with a personal income" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:transaction_type) { "income" }
      let(:title)            { "Salary" }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as income" do
        t = Transaction.find_by(title: title, user_id: user.id)
        expect(t).to be_present
        expect(t.transaction_type).to eq("income")
      end
    end

    context "when currency_id is omitted" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "defaults to the account currency" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: title)
        expect(t.currency_id).to eq(account.currency_id)
      end
    end

    context "when optional note is provided" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: transaction_type,
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date,
          note:             "Weekly shop"
        }
      end

      it "returns 201 and persists the note" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: title)
        expect(t.note).to eq("Weekly shop")
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when account_id does not belong to the current user" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: transaction_type,
          account_id:       other_account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when category_id does not belong to the current user" do
      let(:other_category)  { create(:category) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: transaction_type,
          account_id:       account.id,
          category_id:      other_category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when category_id references a default category assigned to the current user" do
      let(:category)        { user.categories.find_by!(name: "Groceries") }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and uses the category" do
        expect(response).to have_http_status(:created)
        expect(Transaction.find_by(title: title, user_id: user.id)&.category_id).to eq(category.id)
      end
    end

    context "when creating a transfer transaction" do
      let(:to_account)      { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Wallet top-up",
          amount_cents:     3000,
          transaction_type: "transfer",
          from_account_id:  account.id,
          to_account_id:    to_account.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists as a transfer with correct account references" do
        t = Transaction.find_by(title: "Wallet top-up", user_id: user.id)
        expect(t).to be_present
        expect(t.transaction_type).to eq("transfer")
        expect(t.account_id).to eq(account.id)
        expect(t.transfer_account_id).to eq(to_account.id)
      end

      it "deducts from from_account and credits to_account" do
        expect(account.reload.current_balance_cents).to eq(-3000)
        expect(to_account.reload.current_balance_cents).to eq(3000)
      end
    end

    context "when transaction_type is transfer but from_account_id is missing" do
      let(:to_account)       { create(:account, user: user, currency: currency) }
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:transaction_type) { "transfer" }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: "transfer",
          to_account_id:    to_account.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction_type is transfer but to_account_id is missing" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: "transfer",
          from_account_id:  account.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when from_account_id and to_account_id are the same" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: "transfer",
          from_account_id:  account.id,
          to_account_id:    account.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when from_account_id does not belong to the current user" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:to_account)      { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: "transfer",
          from_account_id:  other_account.id,
          to_account_id:    to_account.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when to_account_id does not belong to the current user" do
      let(:other_account)   { create(:account, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: "transfer",
          from_account_id:  account.id,
          to_account_id:    other_account.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when amount_cents is zero" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:amount_cents)    { 0 }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when title is blank" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:title)           { "" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction_date is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            title,
          amount_cents:     amount_cents,
          transaction_type: transaction_type,
          account_id:       account.id,
          category_id:      category.id
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when transaction_date is not a valid datetime" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:transaction_date) { "not-a-date" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
