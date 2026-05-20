# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Friendships", type: :request do
  let(:headers)    { { "Content-Type" => "application/json" } }
  let(:requester)  { create(:user) }
  let(:receiver)   { create(:user) }
  let(:friendship) { create(:friendship, sender: requester, receiver: receiver) }

  describe "DELETE /api/v0/friendships/:id" do
    let(:endpoint)        { "/api/v0/friendships/#{friendship.id}" }
    let(:request_headers) { headers }

    before do
      delete endpoint, headers: request_headers
    end

    # SUCCESS PATHS
    context "when the requester deletes their own pending request" do
      let(:request_headers) { headers.merge(auth_headers(requester)) }

      it "returns 200" do
        expect(response).to have_http_status(:ok)
      end

      it "removes the friendship" do
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

    context "when the receiver tries to delete a pending request" do
      let(:request_headers) { headers.merge(auth_headers(receiver)) }

      it "returns 403 and matches error schema" do
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the requester tries to delete an accepted friendship" do
      let(:request_headers) { headers.merge(auth_headers(requester)) }
      let(:friendship)      { create(:friendship, :accepted, sender: requester, receiver: receiver) }

      it "returns 403 and matches error schema" do
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when a user not involved in the friendship tries to delete it" do
      let(:outsider)        { create(:user) }
      let(:request_headers) { headers.merge(auth_headers(outsider)) }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when the friendship does not exist" do
      let(:request_headers) { headers.merge(auth_headers(requester)) }
      let(:endpoint)        { "/api/v0/friendships/0" }

      it "returns 404 and matches error schema" do
        expect(response).to have_http_status(:not_found)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
