# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Users", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user, onboarding_completed: false) }
  let(:request_headers) { headers }

  describe "PATCH /api/v0/me" do
    let(:endpoint)       { "/api/v0/me" }
    let(:request_params) { { onboarding_completed: true } }

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("users/update_me_response")
      end

      it "updates onboarding_completed" do
        expect(user.reload.onboarding_completed).to be(true)
        expect(JSON.parse(response.body).dig("user", "onboarding_completed")).to be(true)
      end
    end

    context "when authenticated and updating password with the correct current password" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          current_password: "Password1!",
          password: "NewPassword1!",
          password_confirmation: "NewPassword1!"
        }
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("users/update_me_response")
      end

      it "updates the password" do
        expect(user.reload.valid_password?("NewPassword1!")).to be(true)
      end
    end

    context "when authenticated and updating password with the wrong current password" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          current_password: "WrongPassword1!",
          password: "NewPassword1!",
          password_confirmation: "NewPassword1!"
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end

      it "does not update the password" do
        expect(user.reload.valid_password?("Password1!")).to be(true)
        expect(user.valid_password?("NewPassword1!")).to be(false)
      end
    end

    context "when authenticated and updating password without current password" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params) do
        {
          password: "NewPassword1!",
          password_confirmation: "NewPassword1!"
        }
      end

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end

      it "does not update the password" do
        expect(user.reload.valid_password?("Password1!")).to be(true)
        expect(user.valid_password?("NewPassword1!")).to be(false)
      end
    end

    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when onboarding_completed is invalid" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      # yes/no are valid somehow here
      let(:request_params)  { { onboarding_completed: "so" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
