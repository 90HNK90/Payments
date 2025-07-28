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

ActiveRecord::Schema[7.2].define(version: 2025_07_28_164741) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "currency", ["AUD", "USD", "SGD", "VND"]
  create_enum "job_status", ["pending", "success", "failed"]
  create_enum "payment_status", ["pending", "exporting", "exported"]

  create_table "company", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.boolean "active", default: true, null: false
    t.index ["name"], name: "one_active_company_name", unique: true, where: "(active = true)"
  end

  create_table "configuration", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "value", null: false
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "job", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.enum "status", default: "pending", null: false, enum_type: "job_status"
    t.datetime "executed_at"
    t.datetime "updated_at"
    t.string "output"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "employee_id", null: false
    t.uuid "batch_id", null: false
    t.string "bsb", limit: 6, null: false
    t.string "account", limit: 9, null: false
    t.bigint "amount_cents", null: false
    t.enum "currency", default: "AUD", null: false, enum_type: "currency"
    t.date "pay_date", null: false
    t.enum "status", default: "pending", null: false, enum_type: "payment_status"
    t.uuid "company_id", null: false
    t.uuid "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_payments_on_company_id"
    t.index ["employee_id", "company_id", "batch_id"], name: "one_pending_payment_per_batch", unique: true, where: "(status = 'pending'::payment_status)"
    t.index ["job_id"], name: "index_payments_on_job_id"
  end

  add_foreign_key "payments", "company"
  add_foreign_key "payments", "job"
end
