# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:group)           { create(:group, created_by: user) }
  let!(:membership)     { create(:groups_user, group: group, user: user) }
  let(:request_headers) { headers }

  describe "DELETE /api/v0/groups/:id/leave" do
    let(:endpoint) { "/api/v0/groups/#{group.id}/leave" }

    before { delete endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated as a group member" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "removes the user from the group" do
        expect(group.users.reload).not_to include(user)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when authenticated but not a member of the group" do
      let(:non_member)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(non_member)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when group does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups/0/leave" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
