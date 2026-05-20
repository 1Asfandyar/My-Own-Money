# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:other_user)      { create(:user) }
  let(:group)           { create(:group, created_by: user) }
  let!(:membership)     { create(:groups_user, group: group, user: user) }
  let(:request_headers) { headers }

  describe "POST /api/v0/groups/:id/members" do
    let(:endpoint)  { "/api/v0/groups/#{group.id}/members" }
    let(:user_ids)  { [ other_user.id ] }

    let(:request_params) { { user_ids: user_ids } }

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated as a group member with valid user_ids" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/add_members_response")
      end

      it "adds the users to the group" do
        expect(group.users.reload).to include(other_user)
      end
    end

    context "when adding a user already in the group" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [ user.id ] }

      it "returns 200 without duplicating the membership" do
        expect(response).to have_http_status(:ok)
        expect(group.users.where(id: user.id).count).to eq(1)
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
      let(:non_member)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(non_member)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when group does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups/0/members" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when a user_id does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [ 0 ] }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when user_ids is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { {} }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
