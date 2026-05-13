# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Currencies", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "GET /api/v0/currencies" do
    let(:endpoint)        { "/api/v0/currencies" }
    let(:request_headers) { headers }

    before { get endpoint, headers: request_headers }

    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("currencies/index_response")
      end

      it "returns an empty list when no currencies exist" do
        data = JSON.parse(response.body)
        expect(data["currencies"]).to eq([])
      end
    end

    context "when authenticated with existing currencies" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let!(:usd)            { create(:currency, code: "USD", name: "US Dollar", symbol: "$") }
      let!(:eur)            { create(:currency, code: "EUR", name: "Euro", symbol: "EUR") }

      before { get endpoint, headers: request_headers }

      it "returns all currencies ordered by code ascending" do
        data = JSON.parse(response.body)

        expect(data["currencies"].size).to eq(2)
        expect(data["currencies"].map { |currency| currency["code"] }).to eq(%w[EUR USD])
      end
    end

    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
