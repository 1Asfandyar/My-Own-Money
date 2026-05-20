# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Groups", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }
  let(:other_user)      { create(:user) }
  let(:request_headers) { headers }
  let(:endpoint)        { "/api/v0/groups" }

  describe "GET /api/v0/groups" do
    before { get endpoint, headers: request_headers }

    context "when authenticated" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let!(:custom_group)   { create(:group, created_by: user, name: "Trip") }
      let!(:membership)     { create(:groups_user, group: custom_group, user: user) }

      it "returns 200 and matches schema" do
        expect(response).to be_ok
        expect(response).to match_json_schema("groups/index_response")
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
