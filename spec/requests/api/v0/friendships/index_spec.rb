# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V0::Friendships", type: :request do
  let(:headers)         { { "Content-Type" => "application/json" } }
  let(:user)            { create(:user) }

  let(:accepted_friend)  { create(:user) }
  let(:outgoing_target)  { create(:user) }
  let(:incoming_sender)  { create(:user) }
  let(:blocked_friend)   { create(:user) }
  let(:blocked_sender)   { create(:user) }

  # All data created eagerly at describe scope so it exists before the before block fires.
  let!(:f_accepted)    { create(:friendship, :accepted, sender: user, receiver: accepted_friend) }
  let!(:f_outgoing)    { create(:friendship, sender: user, receiver: outgoing_target) }
  let!(:f_incoming)    { create(:friendship, sender: incoming_sender, receiver: user) }
  let!(:f_blocked_out) { create(:friendship, :blocked, sender: user, receiver: blocked_friend) }
  let!(:f_blocked_in)  { create(:friendship, :blocked, sender: blocked_sender, receiver: user) }

  # Debt seeding — override `debt` in child contexts; nil means no debt (settled_up).
  # let! forces evaluation before the inner before { get ... } block fires.
  let(:debt)         { nil }
  let!(:_setup_debt) { debt }

  describe "GET /api/v0/friendships" do
    let(:endpoint)        { "/api/v0/friendships" }
    let(:request_headers) { headers }
    let(:request_params)  { {} }

    before do
      get endpoint, params: request_params, headers: request_headers
    end

    # SUCCESS PATHS
    context "when authenticated with no filters (default: accepted friends)" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns 200, matches schema, and includes only accepted friendships" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/index_response")
        ids = JSON.parse(response.body)["friendships"].map { |f| f["id"] }
        expect(ids).to include(f_accepted.id)
        expect(ids).not_to include(f_outgoing.id, f_incoming.id, f_blocked_out.id)
      end
    end

    context "when filtering by incoming pending requests" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { filter: "incoming" } }

      it "returns 200 and includes only incoming pending requests" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/index_response")
        ids = JSON.parse(response.body)["friendships"].map { |f| f["id"] }
        expect(ids).to include(f_incoming.id)
        expect(ids).not_to include(f_outgoing.id, f_accepted.id)
      end
    end

    context "when filtering by outgoing pending requests" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { filter: "outgoing" } }

      it "returns 200 and includes only outgoing pending requests" do
        expect(response).to have_http_status(:ok)
        ids = JSON.parse(response.body)["friendships"].map { |f| f["id"] }
        expect(ids).to include(f_outgoing.id)
        expect(ids).not_to include(f_incoming.id, f_accepted.id)
      end
    end

    context "when filtering by status=blocked" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { status: "blocked" } }

      it "returns 200 and includes only blocked friendships" do
        expect(response).to have_http_status(:ok)
        ids = JSON.parse(response.body)["friendships"].map { |f| f["id"] }
        expect(ids).to include(f_blocked_out.id, f_blocked_in.id)
        expect(ids).not_to include(f_accepted.id, f_outgoing.id)
      end
    end

    context "when combining filter=incoming with status=blocked" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { filter: "incoming", status: "blocked" } }

      it "returns 200 and includes only incoming blocked friendships" do
        expect(response).to have_http_status(:ok)
        ids = JSON.parse(response.body)["friendships"].map { |f| f["id"] }
        expect(ids).to include(f_blocked_in.id)
        expect(ids).not_to include(f_blocked_out.id, f_accepted.id)
      end
    end

    context "when the accepted friend owes the current user" do
      let(:debt)            { create(:debt, from_user: accepted_friend, to_user: user, amount_cents: 500) }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns balance with type owes_you and correct amount" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/index_response")
        balance = JSON.parse(response.body)["friendships"]
                      .find { |f| f["id"] == f_accepted.id }["balance"]
        expect(balance["type"]).to eq("owes_you")
        expect(balance["amount_cents"]).to eq(500)
      end
    end

    context "when the current user owes the accepted friend" do
      let(:debt)            { create(:debt, from_user: user, to_user: accepted_friend, amount_cents: 330) }
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns balance with type you_owe and correct amount" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/index_response")
        balance = JSON.parse(response.body)["friendships"]
                      .find { |f| f["id"] == f_accepted.id }["balance"]
        expect(balance["type"]).to eq("you_owe")
        expect(balance["amount_cents"]).to eq(330)
      end
    end

    context "when there is no debt with the accepted friend" do
      let(:request_headers) { headers.merge(auth_headers(user)) }

      it "returns balance with type settled_up and amount 0" do
        expect(response).to have_http_status(:ok)
        expect(response).to match_json_schema("friendships/index_response")
        balance = JSON.parse(response.body)["friendships"]
                      .find { |f| f["id"] == f_accepted.id }["balance"]
        expect(balance["type"]).to eq("settled_up")
        expect(balance["amount_cents"]).to eq(0)
      end
    end

    # FAILURE PATHS
    context "when unauthenticated" do
      it "returns 401 and matches error schema" do
        expect(response).to have_http_status(:unauthorized)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when filter is an invalid value" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { filter: "invalid" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end

    context "when status is an invalid value" do
      let(:request_headers) { headers.merge(auth_headers(user)) }
      let(:request_params)  { { status: "unknown" } }

      it "returns 422 and matches error schema" do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_json_schema("error_response")
      end
    end
  end
end
