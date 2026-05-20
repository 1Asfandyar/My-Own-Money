# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Friendships", type: :request do
  let(:headers)    { { "Content-Type" => "application/json" } }
  let(:requester)  { create(:user) }
  let(:receiver)   { create(:user) }
  let(:friendship) { create(:friendship, sender: requester, receiver: receiver) }

  describe "PATCH /api/v0/friendships/:id" do
    let(:endpoint)        { "/api/v0/friendships/#{friendship.id}" }
    let(:request_headers) { headers }
    let(:status)          { "accepted" }

    let(:request_params) do
      { status: status }
    end

    before do
      patch endpoint, params: request_params.to_json, headers: request_headers
    end

    # SUCCESS PATHS
    context "when the receiver accepts a pending request" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }
      let(:status)          { "accepted" }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/update_response")
      end

      it "returns the requester as friend from the receiver's perspective" do
        f = JSON.parse(response.body)["friendship"]
        expect(f["friend"]["id"]).to eq(requester.id)
      end

      it "updates the friendship status to accepted" do
        expect(friendship.reload.status).to eq("accepted")
      end
    end

    context "when either party blocks the other" do
      let(:request_headers) { headers.merge(auth_headers(requester)) }
      let(:status)          { "blocked" }

      it "returns 200 and matches schema" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/update_response")
      end

      it "updates the friendship status to blocked" do
        expect(friendship.reload.status).to eq("blocked")
      end
    end

    context "when the receiver blocks on an accepted friendship" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }
      let(:friendship)      { create(:friendship, :accepted, sender: requester, receiver: receiver) }
      let(:status)          { "blocked" }

      it "returns 200 and blocks successfully" do
        expect(response).to have_http_status(:ok)
        expect(friendship.reload.status).to eq("blocked")
      end
    end

    context "when the receiver rejects a pending request" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }
      let(:status)          { "rejected" }

      it "returns 200 and deletes the friendship" do
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["success"]).to be true
        expect(Friendship.find_by(id: friendship.id)).to be_nil
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the requester tries to accept their own request" do
      let(:request_headers) { headers.merge(auth_headers(requester)) }
      let(:status)          { "accepted" }

      it "returns 403 and matches error schema" do
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the requester tries to reject their own request" do
      let(:request_headers) { headers.merge(auth_headers(requester)) }
      let(:status)          { "rejected" }

      it "returns 403 and matches error schema" do
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when trying to accept an already-accepted friendship" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }
      let(:friendship)      { create(:friendship, :accepted, sender: requester, receiver: receiver) }
      let(:status)          { "accepted" }

      it "returns 403 and matches error schema" do
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when a user not involved in the friendship tries to update it" do
      let(:outsider)        { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(outsider)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the friendship does not exist" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }
      let(:endpoint)        { "/api/v0/friendships/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when status is an invalid value" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }
      let(:status)          { "unknown" }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
