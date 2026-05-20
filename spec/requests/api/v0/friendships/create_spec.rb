# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Friendships", type: :request do
  let(:headers)       { { "Content-Type" => "application/json" } }
  let(:user)          { create(:user) }
  let(:other_user)    { create(:user) }
  let(:pre_existing_target) { create(:user) }

  # Friendship with pre_existing_target is created eagerly so it exists when the request fires.
  let!(:pre_existing) { create(:friendship, sender: user, receiver: pre_existing_target) }

  describe "POST /api/v0/friendships" do
    let(:endpoint)        { "/api/v0/friendships" }
    let(:request_headers) { headers }
    let(:user_ids)        { [ other_user.id ] }

    let(:request_params) do
      { user_ids: user_ids }
    end

    before do
      post endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with valid user_ids" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 201 and matches schema" do
        expect(response).to have_http_status(:created)
        expect(response).to match_json_schema("friendships/create_response")
      end

      it "returns the other user as friend" do
        friendship = JSON.parse(response.body)["friendships"].first
        expect(friendship["friend"]["id"]).to eq(other_user.id)
      end

      it "persists the pending friendship" do
        user_a_id, user_b_id = [ user.id, other_user.id ].minmax
        expect(Friendship.find_by(user_a_id: user_a_id, user_b_id: user_b_id)).to be_present
      end
    end

    context "when requesting friendship with multiple users at once" do
      let(:second_user)     { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [ other_user.id, second_user.id ] }

      it "returns 201 and creates both friendships" do
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["friendships"].size).to eq(2)
      end
    end

    context "when a friendship with the target user already exists" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [ pre_existing_target.id ] }

      it "returns 201 with an empty friendships array (skips duplicate)" do
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["friendships"]).to be_empty
      end
    end

    context "when user_ids includes the current user's own ID" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [ user.id ] }

      it "returns 201 with an empty friendships array (self is skipped)" do
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["friendships"]).to be_empty
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when user_ids contains a non-existent user" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [ 0 ] }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when user_ids is empty" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:user_ids)        { [] }

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
