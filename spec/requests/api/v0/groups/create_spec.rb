# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:user)    { create(:user) }

  describe "POST /api/v0/groups" do
    let(:endpoint)        { "/api/v0/groups" }
    let(:request_headers) { headers }
    let(:name)            { "Trip to Lahore" }
    let(:description)     { "Expenses for the trip" }

    let(:request_params) do
      { name: name, description: description }
    end

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with valid params" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("groups/create_response")
      end

      it "persists the group and adds the creator as a member" do
        group = Group.find_by(name: name)
        expect(group).to be_present
        expect(group.users).to include(user)
      end
    end

    context "when authenticated with only a name (description optional)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { name: name } }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("groups/create_response")
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when name is blank" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:name)            { "" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
