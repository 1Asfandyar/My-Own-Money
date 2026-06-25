require "rails_helper"

RSpec.describe Friendship, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user_a).class_name("User") }
    it { is_expected.to belong_to(:user_b).class_name("User") }
    it { is_expected.to belong_to(:requested_by).class_name("User") }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, accepted: 1, blocked: 2) }
  end

  describe "validations" do
    subject(:friendship) { build(:friendship) }

    it "is valid with valid attributes" do
      expect(friendship).to be_valid
    end

    context "when status is nil" do
      it "is invalid" do
        friendship.status = nil

        expect(friendship).not_to be_valid
        expect(friendship.errors[:status]).to be_present
      end
    end

    context "when user_a and user_b are the same user" do
      it "is invalid and adds an error to user_b_id" do
        user = create(:user)
        duplicate = Friendship.new(user_a: user, user_b: user, requested_by: user, status: :pending)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_b_id]).to include("must be different from user_a")
      end
    end

    context "when user_a_id is greater than user_b_id" do
      it "is invalid and adds an error to user_a_id" do
        first_user  = create(:user)
        second_user = create(:user)
        larger      = [ first_user, second_user ].max_by(&:id)
        smaller     = [ first_user, second_user ].min_by(&:id)

        out_of_order = Friendship.new(
          user_a:       larger,
          user_b:       smaller,
          requested_by: larger,
          status:       :pending
        )

        expect(out_of_order).not_to be_valid
        expect(out_of_order.errors[:user_a_id]).to include("must be less than user_b_id")
      end
    end

    context "when user_a_id is less than user_b_id" do
      it "is valid" do
        first_user  = create(:user)
        second_user = create(:user)
        smaller = [ first_user, second_user ].min_by(&:id)
        larger  = [ first_user, second_user ].max_by(&:id)

        correctly_ordered = Friendship.new(
          user_a:       smaller,
          user_b:       larger,
          requested_by: smaller,
          status:       :pending
        )

        expect(correctly_ordered).to be_valid
      end
    end

    context "when a friendship already exists between the same two users" do
      it "raises a database uniqueness constraint error on duplicate" do
        first_user  = create(:user)
        second_user = create(:user)
        smaller = [ first_user, second_user ].min_by(&:id)
        larger  = [ first_user, second_user ].max_by(&:id)

        Friendship.create!(user_a: smaller, user_b: larger, requested_by: smaller, status: :pending)

        expect {
          Friendship.create!(user_a: smaller, user_b: larger, requested_by: larger, status: :pending)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "scopes" do
    let!(:pending_friendship)  { create(:friendship) }
    let!(:accepted_friendship) { create(:friendship, :accepted, sender: create(:user), receiver: create(:user)) }
    let!(:blocked_friendship)  { create(:friendship, :blocked,  sender: create(:user), receiver: create(:user)) }

    describe ".pending" do
      it "returns only pending friendships" do
        expect(Friendship.pending).to contain_exactly(pending_friendship)
      end
    end

    describe ".accepted" do
      it "returns only accepted friendships" do
        expect(Friendship.accepted).to contain_exactly(accepted_friendship)
      end
    end
  end

  describe "#other_user" do
    let(:first_user)  { create(:user) }
    let(:second_user) { create(:user) }
    let(:user_a)      { [ first_user, second_user ].min_by(&:id) }
    let(:user_b)      { [ first_user, second_user ].max_by(&:id) }
    let(:friendship) do
      Friendship.create!(user_a: user_a, user_b: user_b, requested_by: user_a, status: :accepted)
    end

    it "returns user_b when called with user_a" do
      expect(friendship.other_user(user_a)).to eq(user_b)
    end

    it "returns user_a when called with user_b" do
      expect(friendship.other_user(user_b)).to eq(user_a)
    end
  end

  describe "#involves?" do
    let(:outsider)   { create(:user) }
    let(:friendship) { create(:friendship) }

    it "returns true for user_a" do
      expect(friendship.involves?(friendship.user_a)).to be(true)
    end

    it "returns true for user_b" do
      expect(friendship.involves?(friendship.user_b)).to be(true)
    end

    it "returns false for a user not in the friendship" do
      expect(friendship.involves?(outsider)).to be(false)
    end
  end
end
