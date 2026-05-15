class AddMetadataToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :icon, :string
    add_column :categories, :color, :string
  end
end
