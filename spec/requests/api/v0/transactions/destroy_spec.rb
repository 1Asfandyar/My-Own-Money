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

  describe "DELETE /api/v0/transactions/:id" do
    let(:endpoint)        { "/api/v0/transactions/#{transaction.id}" }
    let(:request_headers) { headers }

    before { delete endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated as the transaction owner" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/destroy_response")
      end

      it "removes the transaction" do
        expect(Transaction.find_by(id: transaction.id)).to be_nil
      end

      it "reverts the account balance" do
        # account started at 0: expense reverted → +5000
        expect(account.reload.current_balance_cents).to eq(5000)
      end
    end

    context "when the personal transaction has a category" do
      let(:category)        { create(:category, user: user, balance_cents: 5000) }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "reverts the category balance_cents to 0" do
        expect(category.reload.balance_cents).to eq(0)
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

    context "when deleting a transfer transaction" do
      let(:endpoint)        { "/api/v0/transactions/#{transfer_transaction.id}" }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("transactions/destroy_response")
      end

      it "removes the transfer transaction" do
        expect(Transaction.find_by(id: transfer_transaction.id)).to be_nil
      end

      it "reverts both account balances" do
        # account was at -2000 (deducted by transfer setup): revert → 0
        expect(account.reload.current_balance_cents).to eq(0)
        # to_account was at +2000 (credited by transfer setup): revert → 0
        expect(to_account.reload.current_balance_cents).to eq(0)
      end
    end
  end
end
