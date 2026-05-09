class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text   :description
      t.timestamps
    end
  end
end
