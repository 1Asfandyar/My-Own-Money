# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Auth", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }

  describe "POST /api/v0/auth/google" do
    let(:endpoint)       { "/api/v0/auth/google" }
    let(:google_token)   { "valid.google.id.token" }
    let(:request_params) { { token: google_token } }
    let(:request_headers) { headers }

    let(:google_payload) do
      {
        "sub"            => "google-uid-123",
        "email"          => "googleuser@example.com",
        "name"           => "Google User",
        "email_verified" => true
      }
    end

    # nil means no error — override in failure contexts to simulate a bad token
    let(:google_validation_error) { nil }

    before do
      validator = instance_double(GoogleIDToken::Validator)
      allow(GoogleIDToken::Validator).to receive(:new).and_return(validator)

      if google_validation_error
        allow(validator).to receive(:check).and_raise(
          GoogleIDToken::ValidationError, google_validation_error
        )
      else
        allow(validator).to receive(:check).with(google_token, anything).and_return(google_payload)
      end

      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when token is valid and email is verified" do
      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("auth/google_login_response")
      end

      it "sets Authorization header" do
        expect(response.headers["Authorization"]).to match(/\ABearer .+\z/)
      end

      it "creates the user" do
        expect(User.find_by(email: "googleuser@example.com")).to be_present
      end
    end

    context "when user already exists with the same email" do
      around do |example|
        create(:user, email: "googleuser@example.com")
        example.run
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("auth/google_login_response")
      end

      it "does not create a duplicate user" do
        expect(User.where(email: "googleuser@example.com").count).to eq(1)
      end
    end

    # FAILURE PATHS
    context "when token param is missing" do
      let(:request_params) { {} }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the Google token is invalid" do
      let(:google_validation_error) { "Signature verification failed" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the Google account email is not verified" do
      let(:google_payload) { super().merge("email_verified" => false) }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
