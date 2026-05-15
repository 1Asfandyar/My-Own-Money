# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_13_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.integer "current_balance_cents", default: 0, null: false
    t.integer "initial_balance_cents", default: 0, null: false
    t.boolean "is_archived", default: false, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["currency_id"], name: "index_accounts_on_currency_id"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index "(true)", name: "index_admin_users_singleton", unique: true
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.integer "category_type", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "currencies", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_currencies_on_code", unique: true
  end

  create_table "debts", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "from_user_id", null: false
    t.bigint "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_user_id", "to_user_id"], name: "index_debts_on_from_user_id_and_to_user_id", unique: true
    t.index ["from_user_id"], name: "index_debts_on_from_user_id"
    t.index ["to_user_id"], name: "index_debts_on_to_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
  end

  create_table "groups_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id", "user_id"], name: "index_groups_users_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_groups_users_on_group_id"
    t.index ["user_id"], name: "index_groups_users_on_user_id"
  end

  create_table "jwt_blacklists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp"
    t.string "jti"
    t.datetime "updated_at", null: false
  end

  create_table "transaction_splits", force: :cascade do |t|
    t.decimal "allocation_value", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.integer "owed_amount_cents", null: false
    t.integer "split_method", null: false
    t.bigint "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["transaction_id"], name: "index_transaction_splits_on_transaction_id"
    t.index ["user_id"], name: "index_transaction_splits_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "amount_cents", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.bigint "group_id"
    t.text "note"
    t.string "title", null: false
    t.datetime "transaction_date", null: false
    t.integer "transaction_type", null: false
    t.bigint "transfer_account_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "visibility_type", null: false
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["currency_id"], name: "index_transactions_on_currency_id"
    t.index ["group_id"], name: "index_transactions_on_group_id"
    t.index ["transaction_date"], name: "index_transactions_on_transaction_date"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name"
    t.string "mobile_number"
    t.boolean "onboarding_completed", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["mobile_number"], name: "index_users_on_mobile_number", unique: true, where: "(mobile_number IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "accounts", "currencies"
  add_foreign_key "accounts", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "debts", "users", column: "from_user_id"
  add_foreign_key "debts", "users", column: "to_user_id"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "groups_users", "groups"
  add_foreign_key "groups_users", "users"
  add_foreign_key "transaction_splits", "transactions"
  add_foreign_key "transaction_splits", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "accounts", column: "transfer_account_id"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "currencies"
  add_foreign_key "transactions", "groups"
  add_foreign_key "transactions", "users"
end
