class AddProfileFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :full_name, :string
    add_column :users, :mobile_number, :string

    add_index :users, :mobile_number, unique: true, where: 'mobile_number IS NOT NULL'
  end
end
