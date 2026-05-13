module Categories
  class AssignDefaults
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      Category.transaction do
        Defaults.all.each { |attributes| upsert_category(attributes) }
      end
    end

    private

    attr_reader :user

    def upsert_category(attributes)
      category = user.categories.find_or_initialize_by(
        name: attributes[:name],
        category_type: attributes[:category_type]
      )

      assign_missing_metadata(category, attributes)
      category.save! if category.new_record? || category.changed?
    end

    def assign_missing_metadata(category, attributes)
      attributes.slice(:icon, :color).each do |name, value|
        category[name] = value if category[name].blank?
      end
    end
  end
end
