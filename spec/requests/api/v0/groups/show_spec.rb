# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:group)           { create(:group, created_by: user) }
  let!(:membership)     { create(:groups_user, group: group, user: user) }
  let(:request_headers) { headers }

  describe "GET /api/v0/groups/:id" do
    let(:endpoint) { "/api/v0/groups/#{group.id}" }

    before { get endpoint, headers: request_headers }

    # SUCCESS PATHS
    context "when authenticated as a group member" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let!(:transaction)    { create(:transaction, user: user, group: group, visibility_type: :shared) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/show_response")
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
  end
end
