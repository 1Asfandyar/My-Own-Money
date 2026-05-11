# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:other_user)      { create(:user) }
  let(:group)           { create(:group, created_by: user) }
  let!(:membership)     { create(:groups_user, group: group, user: user) }
  let!(:other_membership) { create(:groups_user, group: group, user: other_user) }
  let(:request_headers) { headers }

  describe "DELETE /api/v0/groups/:id/members/:user_id" do
    let(:endpoint) { "/api/v0/groups/#{group.id}/members/#{other_user.id}" }

    before { delete endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated as a group member removing another member" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "removes the member from the group" do
        expect(group.users.reload).not_to include(other_user)
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
      let(:endpoint)        { "/api/v0/groups/0/members/#{other_user.id}" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the target user does not exist" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups/#{group.id}/members/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the target user is not a member of the group" do
      let(:non_member)      { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups/#{group.id}/members/#{non_member.id}" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
