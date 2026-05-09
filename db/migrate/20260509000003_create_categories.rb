class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :name,          null: false
      t.integer :category_type, null: false
      t.timestamps
    end
  end
end
