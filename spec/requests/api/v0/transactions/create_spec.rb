# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Transactions", type: :request do
  let(:headers)  { { "Content-Type" => "application/json" } }
  let(:user)     { create(:user) }
  let(:currency) { create(:currency) }
  let(:account)  { create(:account, user: user, currency: currency) }
  let(:category) { create(:category, user: user) }

  # Additional users for shared expense scenarios
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }

  describe "POST /api/v0/transactions" do
    let(:endpoint)          { "/api/v0/transactions" }
    let(:request_headers)   { headers }
    let(:title)             { "Groceries" }
    let(:amount_cents)      { 5000 }
    let(:transaction_type)  { "expense" }
    let(:transaction_date)  { "2026-05-12T10:00:00Z" }

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

    # ─────────────────────────────────────────────────────────────────────────
    # SUCCESS PATHS
    # ─────────────────────────────────────────────────────────────────────────

    context "when authenticated with a personal expense" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as a personal expense" do
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

    context "when transaction_date is omitted" do
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

      it "returns 201 and defaults the date to today" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: title, user_id: user.id)
        expect(t.transaction_date.to_date).to eq(Date.today)
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

    # ── Shared expense: equal split ───────────────────────────────────────────

    context "when creating a shared expense with equal split (payer in shared_by)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Shared Dinner",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id, user3.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as a shared expense" do
        t = Transaction.find_by(title: "Shared Dinner")
        expect(t).to be_present
        expect(t.visibility_type).to eq("shared")
        expect(t.transaction_type).to eq("expense")
        expect(t.user_id).to eq(user.id)
        expect(t.amount_cents).to eq(3000)
      end

      it "creates three equal splits" do
        t = Transaction.find_by(title: "Shared Dinner")
        splits = t.transaction_splits.order(:owed_amount_cents)
        expect(splits.count).to eq(3)
        expect(splits.map(&:owed_amount_cents).sum).to eq(3000)
        expect(splits.map(&:split_method).uniq).to eq([ "equal" ])
      end

      it "creates debts for the non-payer sharers" do
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(1000)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(1000)
      end

      it "does not create a debt for the payer's own share" do
        expect(Debt.find_by(from_user_id: user.id, to_user_id: user.id)).to be_nil
      end

      it "deducts the full amount from the payer's account" do
        expect(account.reload.current_balance_cents).to eq(-3000)
      end
    end

    context "when creating a shared expense with equal split (payer not in shared_by)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Paid for others",
          amount_cents:     2000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user2.id, user3.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "creates splits only for the shared_by users" do
        t = Transaction.find_by(title: "Paid for others")
        expect(t.transaction_splits.count).to eq(2)
        split_user_ids = t.transaction_splits.pluck(:user_id)
        expect(split_user_ids).to contain_exactly(user2.id, user3.id)
      end

      it "creates a debt for each sharer toward the payer" do
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(1000)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(1000)
      end
    end

    context "when only the payer is in shared_by" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Solo covered",
          amount_cents:     1500,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201, creates one split, and creates no debts" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: "Solo covered")
        expect(t.transaction_splits.count).to eq(1)
        expect(t.transaction_splits.first.owed_amount_cents).to eq(1500)
        expect(Debt.count).to eq(0)
      end
    end

    context "when transaction_date is omitted for a shared expense" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Date-less shared",
          amount_cents:     1000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id
        }
      end

      it "returns 201 and defaults the date to today" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: "Date-less shared")
        expect(t.transaction_date.to_date).to eq(Date.today)
      end
    end

    context "when amount does not divide evenly among sharers" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Uneven split",
          amount_cents:     1000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id, user3.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and gives the remainder to the first user in shared_by" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: "Uneven split")
        splits = t.transaction_splits.order(
          Arel.sql("CASE WHEN user_id = #{user.id} THEN 0 ELSE 1 END")
        )
        # 1000 / 3 = 333 remainder 1 → first user gets 334, others get 333
        expect(splits.first.owed_amount_cents).to eq(334)
        expect(splits.map(&:owed_amount_cents).sum).to eq(1000)
      end
    end

    context "when a same-direction debt already exists between sharer and payer" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      # user2 already owes user 500; the new split adds another 600 → total 1100
      let(:existing_debt) { create(:debt, from_user: user2, to_user: user, amount_cents: 500) }
      let(:request_params) do
        existing_debt # force creation before the request fires
        {
          title:            "Dinner netting same dir",
          amount_cents:     1200,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "adds the new share to the existing debt" do
        expect(response).to have_http_status(:created)
        debt = Debt.find_by(from_user_id: user2.id, to_user_id: user.id)
        expect(debt.amount_cents).to eq(1100) # 500 + 600
      end
    end

    context "when an opposite-direction debt exists (payer owes the sharer)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      # user currently owes user2 800; user2 now owes user 600 → net: user still owes user2 200
      let(:existing_debt) { create(:debt, from_user: user, to_user: user2, amount_cents: 800) }
      let(:request_params) do
        existing_debt
        {
          title:            "Dinner netting reverse",
          amount_cents:     1200,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "reduces the opposite-direction debt by the new share" do
        expect(response).to have_http_status(:created)
        debt = Debt.find_by(from_user_id: user.id, to_user_id: user2.id)
        expect(debt.amount_cents).to eq(200) # 800 - 600
      end
    end

    context "when an opposite-direction debt nets to exactly zero" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      # user owes user2 600; user2 now owes user 600 → net = 0, debt deleted
      let(:existing_debt) { create(:debt, from_user: user, to_user: user2, amount_cents: 600) }
      let(:request_params) do
        existing_debt
        {
          title:            "Dinner zero net",
          amount_cents:     1200,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "sets the debt row to zero when the balance reaches zero" do
        expect(response).to have_http_status(:created)
        debt = Debt.find_by(from_user_id: user.id, to_user_id: user2.id)
        expect(debt).not_to be_nil
        expect(debt.amount_cents).to eq(0)
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)).to be_nil
      end
    end

    context "when an opposite-direction debt flips direction after netting" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      # user owes user2 400; user2 now owes user 600 → user2 ends up owing user 200
      let(:existing_debt) { create(:debt, from_user: user, to_user: user2, amount_cents: 400) }
      let(:request_params) do
        existing_debt
        {
          title:            "Dinner flip",
          amount_cents:     1200,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "flips the debt direction and stores the net amount" do
        expect(response).to have_http_status(:created)
        # Old direction (user → user2) should be gone or updated
        expect(Debt.find_by(from_user_id: user.id, to_user_id: user2.id)).to be_nil
        # New direction: user2 → user = 600 - 400 = 200
        debt = Debt.find_by(from_user_id: user2.id, to_user_id: user.id)
        expect(debt.amount_cents).to eq(200)
      end
    end

    # ── Shared expense: exact split ───────────────────────────────────────────

    context "when creating a shared expense with exact split (payer in user_shares)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Exact Dinner",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 1000 },
            { user_id: user2.id, share: 800 },
            { user_id: user3.id, share: 1200 }
          ],
          split_method:     "exact",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as a shared expense" do
        t = Transaction.find_by(title: "Exact Dinner")
        expect(t).to be_present
        expect(t.visibility_type).to eq("shared")
        expect(t.transaction_type).to eq("expense")
        expect(t.amount_cents).to eq(3000)
      end

      it "creates splits with the exact per-user amounts" do
        t      = Transaction.find_by(title: "Exact Dinner")
        splits = t.transaction_splits.index_by(&:user_id)
        expect(splits[user.id].owed_amount_cents).to eq(1000)
        expect(splits[user2.id].owed_amount_cents).to eq(800)
        expect(splits[user3.id].owed_amount_cents).to eq(1200)
        expect(splits.values.map(&:split_method).uniq).to eq([ "exact" ])
      end

      it "creates debts only for non-payer sharers" do
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(800)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(1200)
        expect(Debt.find_by(from_user_id: user.id, to_user_id: user.id)).to be_nil
      end

      it "deducts the full amount from the payer's account" do
        expect(account.reload.current_balance_cents).to eq(-3000)
      end
    end

    context "when creating a shared expense with exact split (payer not in user_shares)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Exact — payer covers all",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user2.id, share: 1500 },
            { user_id: user3.id, share: 1500 }
          ],
          split_method:     "exact",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and creates splits only for the listed users" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: "Exact — payer covers all")
        expect(t.transaction_splits.pluck(:user_id)).to contain_exactly(user2.id, user3.id)
      end

      it "creates a debt for each sharer toward the payer" do
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(1500)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(1500)
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

    context "when transaction_date is an invalid value" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:transaction_date) { "not-a-date" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
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

    context "when transaction_type is transfer but from_account_id is missing" do
      let(:to_account)      { create(:account, user: user, currency: currency) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
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
      let(:request_headers) { headers.merge(auth_headers(user)) }
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

    # ── Shared expense (equal): failure paths ─────────────────────────────────

    context "when shared_by is present but paid_by is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Shared no payer",
          amount_cents:     3000,
          transaction_type: "expense",
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when shared_by is present but split_method is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Shared no method",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when split_method is an unsupported value" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Bad method",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "bogus_method",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when split_method is percentage but shared_by is provided instead of user_shares" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Wrong param combo",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "percentage",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when shared_by is an empty array" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Empty sharers",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when shared_by contains an unknown user ID" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Ghost user",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, 999_999 ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when paid_by user does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "No payer",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          999_999,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when account_id does not belong to paid_by user" do
      let(:other_account)   { create(:account, currency: currency) } # belongs to a different user
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Wrong account",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       other_account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when category_id does not belong to paid_by user" do
      let(:other_category)  { create(:category) } # belongs to a different user
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Wrong category",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          shared_by:        [ user.id, user2.id ],
          split_method:     "equal",
          account_id:       account.id,
          category_id:      other_category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    # ── Shared expense (exact): failure paths ─────────────────────────────────

    context "when user_shares is present but paid_by is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Exact no payer",
          amount_cents:     3000,
          transaction_type: "expense",
          user_shares:      [ { user_id: user.id, share: 1500 },
                              { user_id: user2.id, share: 1500 } ],
          split_method:     "exact",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when exact split share amounts do not sum to total" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Bad exact sum",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [ { user_id: user.id,  share: 500 },
                              { user_id: user2.id, share: 500 } ],
          split_method:     "exact",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when exact split entries are missing share" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Missing amounts",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [ { user_id: user.id }, { user_id: user2.id } ],
          split_method:     "exact",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when user_shares contains an unknown user ID" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Exact ghost user",
          amount_cents:     3000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [ { user_id: user.id,  share: 1500 },
                              { user_id: 999_999,  share: 1500 } ],
          split_method:     "exact",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    # ── Shared expense: percentage split ─────────────────────────────────────

    context "when creating a shared expense with percentage split (payer in user_shares)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Percentage Dinner",
          amount_cents:     10_000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 50 },
            { user_id: user2.id, share: 30 },
            { user_id: user3.id, share: 20 }
          ],
          split_method:     "percentage",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as a shared expense" do
        t = Transaction.find_by(title: "Percentage Dinner")
        expect(t).to be_present
        expect(t.visibility_type).to eq("shared")
        expect(t.amount_cents).to eq(10_000)
      end

      it "creates splits with the correct percentage-based amounts" do
        t      = Transaction.find_by(title: "Percentage Dinner")
        splits = t.transaction_splits.index_by(&:user_id)
        expect(splits[user.id].owed_amount_cents).to eq(5000)
        expect(splits[user2.id].owed_amount_cents).to eq(3000)
        expect(splits[user3.id].owed_amount_cents).to eq(2000)
        expect(splits.values.map(&:split_method).uniq).to eq([ "percentage" ])
        expect(splits.values.map(&:owed_amount_cents).sum).to eq(10_000)
      end

      it "stores the percentage as allocation_value" do
        t      = Transaction.find_by(title: "Percentage Dinner")
        splits = t.transaction_splits.index_by(&:user_id)
        expect(splits[user.id].allocation_value).to eq(50)
        expect(splits[user2.id].allocation_value).to eq(30)
        expect(splits[user3.id].allocation_value).to eq(20)
      end

      it "creates debts for the non-payer sharers" do
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(3000)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(2000)
        expect(Debt.find_by(from_user_id: user.id, to_user_id: user.id)).to be_nil
      end

      it "deducts the full amount from the payer's account" do
        expect(account.reload.current_balance_cents).to eq(-10_000)
      end
    end

    context "when percentage split amount does not divide evenly" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Uneven percentage",
          amount_cents:     100,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 34 },
            { user_id: user2.id, share: 33 },
            { user_id: user3.id, share: 33 }
          ],
          split_method:     "percentage",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and splits sum to the full amount" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: "Uneven percentage")
        expect(t.transaction_splits.sum(:owed_amount_cents)).to eq(100)
      end
    end

    context "when percentage shares do not sum to 100" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Bad percentage",
          amount_cents:     10_000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 60 },
            { user_id: user2.id, share: 30 }
          ],
          split_method:     "percentage",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when a percentage entry has a non-positive share" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Zero percentage share",
          amount_cents:     10_000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 100 },
            { user_id: user2.id, share: 0 }
          ],
          split_method:     "percentage",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    # ── Shared expense: shares split ──────────────────────────────────────────

    context "when creating a shared expense with shares split" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Shares Dinner",
          amount_cents:     12_000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 1 },
            { user_id: user2.id, share: 2 },
            { user_id: user3.id, share: 3 }
          ],
          split_method:     "shares",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("transactions/create_response")
      end

      it "persists the transaction as a shared expense" do
        t = Transaction.find_by(title: "Shares Dinner")
        expect(t).to be_present
        expect(t.visibility_type).to eq("shared")
        expect(t.amount_cents).to eq(12_000)
      end

      it "creates splits proportional to the share counts" do
        t      = Transaction.find_by(title: "Shares Dinner")
        splits = t.transaction_splits.index_by(&:user_id)
        # total shares = 6; user=1/6, user2=2/6, user3=3/6
        expect(splits[user.id].owed_amount_cents).to eq(2000)
        expect(splits[user2.id].owed_amount_cents).to eq(4000)
        expect(splits[user3.id].owed_amount_cents).to eq(6000)
        expect(splits.values.map(&:split_method).uniq).to eq([ "shares" ])
        expect(splits.values.map(&:owed_amount_cents).sum).to eq(12_000)
      end

      it "stores the share count as allocation_value" do
        t      = Transaction.find_by(title: "Shares Dinner")
        splits = t.transaction_splits.index_by(&:user_id)
        expect(splits[user.id].allocation_value).to eq(1)
        expect(splits[user2.id].allocation_value).to eq(2)
        expect(splits[user3.id].allocation_value).to eq(3)
      end

      it "creates debts for the non-payer sharers" do
        expect(Debt.find_by(from_user_id: user2.id, to_user_id: user.id)&.amount_cents).to eq(4000)
        expect(Debt.find_by(from_user_id: user3.id, to_user_id: user.id)&.amount_cents).to eq(6000)
        expect(Debt.find_by(from_user_id: user.id, to_user_id: user.id)).to be_nil
      end

      it "deducts the full amount from the payer's account" do
        expect(account.reload.current_balance_cents).to eq(-12_000)
      end
    end

    context "when shares split amount does not divide evenly" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Uneven shares",
          amount_cents:     10,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 1 },
            { user_id: user2.id, share: 1 },
            { user_id: user3.id, share: 1 }
          ],
          split_method:     "shares",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 201 and splits sum to the full amount" do
        expect(response).to have_http_status(:created)
        t = Transaction.find_by(title: "Uneven shares")
        expect(t.transaction_splits.sum(:owed_amount_cents)).to eq(10)
      end
    end

    context "when a shares entry has a non-positive share count" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          title:            "Zero share count",
          amount_cents:     12_000,
          transaction_type: "expense",
          paid_by:          user.id,
          user_shares:      [
            { user_id: user.id,  share: 3 },
            { user_id: user2.id, share: 0 }
          ],
          split_method:     "shares",
          account_id:       account.id,
          category_id:      category.id,
          transaction_date: transaction_date
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
