module Api::V0::Transactions
  class SharedTransactionsService
    def initialize(current_user, params)
      @current_user = current_user
      @params = params
    end

    def call
      {
        success: true,
        friends: friend_summaries
      }
    end

    private

    attr_reader :current_user, :params

    def friend_summaries
      grouped_friend_transactions.map do |friend, transactions|
        {
          friend: Api::V0::UserSerializer.render_as_hash(friend),
          transactions: Api::V0::TransactionSerializer.render_as_hash(transactions.uniq, view: :with_friends)
        }
      end
    end

    def grouped_friend_transactions
      friend_transactions.each_with_object({}) do |transaction, grouped|
        friends_for(transaction).each do |friend|
          split = transaction.transaction_splits.find { |s| s.user_id == friend.id }
          split_amount = split&.owed_amount_cents || 0

          transaction.define_singleton_method(:split_amount_cents) { split_amount }

          grouped[friend] ||= []
          grouped[friend] << transaction
        end
      end
    end

    def friend_transactions
      @friend_transactions ||= begin
        scope = Transaction
          .shared
          .left_joins(:transaction_splits)
          .where("transactions.user_id = :user_id OR transaction_splits.user_id = :user_id", user_id: current_user.id)
          .includes(:user, :category, transaction_splits: :user)
          .distinct

        apply_filters(scope).order(transaction_date: :desc)
      end
    end

    def friends_for(transaction)
      ([ transaction.user ] + transaction.transaction_splits.map(&:user))
        .compact
        .uniq
        .reject { |user| user.id == current_user.id }
    end

    def apply_filters(scope)
      scope = scope.where(category_id: params[:category_id]) if params[:category_id]
      scope = scope.where("transaction_date >= ?", Time.parse(params[:date_from])) if params[:date_from]
      scope = scope.where("transaction_date <= ?", Time.parse(params[:date_to]))   if params[:date_to]
      if params[:search].present?
        term  = "%#{params[:search]}%"
        scope = scope.where("title ILIKE ? OR note ILIKE ?", term, term)
      end
      scope
    end
  end
end
