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

    context "when kind is missing" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns OK" do
        expect(response).to be_ok
        expect(response).to match_json_schema("groups/index_response")
      end
    end

    context "when filtering by friends kind" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups?kind=friends" }
      let!(:custom_group)   { create(:group, created_by: user, name: "Trip") }
      let!(:membership)     { create(:groups_user, group: custom_group, user: user) }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/index_response")
      end

      it "returns only the friends group" do
        data = JSON.parse(response.body)

        expect(data["groups"].size).to eq(1)
        expect(data["groups"].first["id"]).to eq(user.friends_group.id)
        expect(data["groups"].first["kind"]).to eq("friends")
      end
    end

    context "when filtering by custom kind" do
      let(:request_headers)  { headers.merge(auth_headers(user)) }
      let(:endpoint)         { "/api/v0/groups?kind=custom" }
      let(:custom_group_one) { create(:group, created_by: user, name: "Trip") }
      let(:custom_group_two) { create(:group, created_by: user, name: "Home") }

      before do
        create(:groups_user, group: custom_group_one, user: user)
        create(:groups_user, group: custom_group_two, user: user)
        other_group = create(:group, created_by: other_user, name: "Hidden")
        create(:groups_user, group: other_group, user: other_user)
        get endpoint, headers: request_headers
      end

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("groups/index_response")
      end

      it "returns only custom groups" do
        data = JSON.parse(response.body)

        expect(data["groups"].map { |group| group["kind"] }).to all(eq("custom"))
        expect(data["groups"].map { |group| group["id"] }).to match_array(
          [ custom_group_one.id, custom_group_two.id ]
        )
      end
    end

    context "when filtering by an invalid kind" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:endpoint)        { "/api/v0/groups?kind=invalid" }

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
