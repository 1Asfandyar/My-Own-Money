# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Reports", type: :request do
  let(:headers)  { { "Content-Type" => "application/json" } }
  let(:user)     { create(:user) }
  let(:currency) { create(:currency) }

  describe "GET /api/v0/reports/summary" do
    let(:endpoint)        { "/api/v0/reports/summary" }
    let(:request_headers) { headers }
    let(:month)           { "2026-06" }

    before do
      get endpoint, params: { month: month }, headers: request_headers
    end

    # SUCCESS PATHS

    context "when authenticated with a month param" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("reports/summary_response")
      end
    end

    context "when authenticated with no month param (defaults to current month)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:month)           { nil }

      before do
        get endpoint, headers: request_headers
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("reports/summary_response")
      end

      it "sets period to the current month" do
        data = JSON.parse(response.body)
        expect(data["report"]["period"]).to eq(Date.current.strftime("%B %Y"))
      end
    end

    context "when user has no transactions" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema with zero totals" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("reports/summary_response")

        data = JSON.parse(response.body)
        overview = data["report"]["overview"]
        expect(overview["total_income_cents"]).to eq(0)
        expect(overview["total_expenses_cents"]).to eq(0)
        expect(overview["net_cents"]).to eq(0)
        expect(overview["savings_rate_percent"]).to eq(0)
        expect(data["report"]["spending_by_category"]).to eq([])
      end
    end

    context "when authenticated with an account" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let!(:account) { create(:account, user: user, currency: currency, current_balance_cents: 50_000) }

      before do
        get endpoint, params: { month: month }, headers: request_headers
      end

      it "includes the account in the response" do
        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data["report"]["accounts"].size).to eq(1)
        expect(data["report"]["accounts"].first["id"]).to eq(account.id)
        expect(data["report"]["total_balance_cents"]).to eq(50_000)
      end
    end

    context "when trend is requested" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns exactly 3 trend months" do
        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data["report"]["trend"].size).to eq(3)
      end

      it "ends on the requested month" do
        data = JSON.parse(response.body)
        last_trend = data["report"]["trend"].last
        expect(last_trend["month_key"]).to eq(month)
      end
    end

    # FAILURE PATHS

    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when month format is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:month)           { "not-a-date" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when month value is out of range" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:month)           { "2026-13" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
