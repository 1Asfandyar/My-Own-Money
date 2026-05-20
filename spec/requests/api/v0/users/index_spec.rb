# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Users", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let!(:friend)         { create(:user, email: "friend@example.com", full_name: "Friend Name") }
  let(:request_headers) { headers }
  let(:endpoint)        { "/api/v0/users?email=friend@example.com" }

  describe "GET /api/v0/users" do
    before { get endpoint, headers: request_headers }

    context "when authenticated with an existing email" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("users/index_response")
      end

      it "returns the matching user" do
        data = JSON.parse(response.body)

        expect(data["users"].size).to eq(1)
        expect(data["users"].first["id"]).to eq(friend.id)
        expect(data["users"].first["email"]).to eq("friend@example.com")
      end
    end

    context "when authenticated with different email casing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/users?email=FRIEND@example.com" }

      it "returns the matching user" do
        data = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(data["users"].first["id"]).to eq(friend.id)
      end
    end

    context "when authenticated with an unknown email" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/users?email=missing@example.com" }

      it "returns an empty users list" do
        data = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(data["users"]).to eq([])
      end
    end

    context "when email is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/users" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
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
