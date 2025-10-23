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

ActiveRecord::Schema[8.0].define(version: 2025_10_23_203703) do
  create_table "ai_usages", force: :cascade do |t|
    t.string "model", null: false
    t.string "feature", null: false
    t.integer "prompt_tokens", default: 0, null: false
    t.integer "completion_tokens", default: 0, null: false
    t.integer "cached_input_tokens", default: 0, null: false
    t.integer "cost_cents", default: 0, null: false
    t.json "meta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_usages_on_created_at"
    t.index ["feature"], name: "index_ai_usages_on_feature"
  end

  create_table "applications", force: :cascade do |t|
    t.integer "job_posting_id"
    t.string "company", null: false
    t.string "role", null: false
    t.text "job_description", null: false
    t.json "flags", default: {}
    t.string "output_path"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company"], name: "index_applications_on_company"
    t.index ["created_at"], name: "index_applications_on_created_at"
    t.index ["job_posting_id"], name: "index_applications_on_job_posting_id"
    t.index ["output_path"], name: "index_applications_on_output_path"
    t.index ["status"], name: "index_applications_on_status"
  end

  create_table "blocked_companies", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "pattern", default: false, null: false
    t.string "reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_blocked_companies_on_name"
    t.index ["pattern"], name: "index_blocked_companies_on_pattern"
  end

  create_table "job_postings", force: :cascade do |t|
    t.string "company", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.string "location"
    t.boolean "remote", default: false
    t.datetime "posted_at"
    t.string "url", null: false
    t.string "source"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "score", default: 0.0, null: false
    t.string "status", default: "suggested", null: false
    t.datetime "applied_at"
    t.datetime "exported_at"
    t.string "external_id"
    t.datetime "last_seen_at"
    t.datetime "ignored_at"
    t.datetime "last_fetch_at"
    t.index ["company"], name: "index_job_postings_on_company"
    t.index ["created_at"], name: "index_job_postings_on_created_at"
    t.index ["last_seen_at"], name: "index_job_postings_on_last_seen_at"
    t.index ["posted_at"], name: "index_job_postings_on_posted_at"
    t.index ["remote"], name: "index_job_postings_on_remote"
    t.index ["source", "external_id"], name: "index_job_postings_on_source_and_external_id", unique: true, where: "external_id IS NOT NULL"
    t.index ["status"], name: "index_job_postings_on_status"
    t.index ["url"], name: "index_job_postings_on_url", unique: true
  end

  create_table "job_skill_assessments", force: :cascade do |t|
    t.integer "job_posting_id", null: false
    t.string "skill_name", null: false
    t.boolean "have", default: false, null: false
    t.integer "proficiency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_posting_id", "skill_name"], name: "index_job_skill_assessments_on_job_posting_id_and_skill_name", unique: true
    t.index ["skill_name"], name: "index_job_skill_assessments_on_skill_name"
  end

  create_table "job_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider", null: false
    t.string "slug", null: false
    t.boolean "active", default: true
    t.datetime "last_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_job_sources_on_active"
    t.index ["provider", "slug"], name: "index_job_sources_on_provider_and_slug", unique: true
  end

  add_foreign_key "applications", "job_postings"
  add_foreign_key "job_skill_assessments", "job_postings"
end
