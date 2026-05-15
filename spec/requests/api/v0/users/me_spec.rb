# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Users", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user, onboarding_completed: true) }
  let(:request_headers) { headers }

  describe "GET /api/v0/me" do
    let(:endpoint) { "/api/v0/me" }

    before { get endpoint, headers: request_headers }

    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("users/me_response")
      end

      it "returns onboarding_completed" do
        data = JSON.parse(response.body)

        expect(data.dig("user", "id")).to eq(user.id)
        expect(data.dig("user", "onboarding_completed")).to be(true)
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
