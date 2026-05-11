# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:group)           { create(:group, created_by: user) }
  let!(:membership)     { create(:groups_user, group: group, user: user) }
  let(:request_headers) { headers }

  describe "PATCH /api/v0/groups/:id" do
    let(:endpoint) { "/api/v0/groups/#{group.id}" }
    let(:name)     { "Updated Group Name" }

    let(:request_params) { { name: name } }

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated as a group member with valid params" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/update_response")
      end

      it "updates the group name" do
        expect(group.reload.name).to eq(name)
      end
    end

    context "when updating description" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { description: "New description" } }

      it "returns 200 and updates the description" do
        expect(response).to have_http_status(:ok)
        expect(group.reload.description).to eq("New description")
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when authenticated as a non-member" do
      let(:other_user)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(other_user)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when group does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
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
