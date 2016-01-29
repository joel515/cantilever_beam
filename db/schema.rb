# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160129165044) do

  create_table "beams", force: :cascade do |t|
    t.string   "name"
    t.float    "length"
    t.float    "width"
    t.float    "height"
    t.float    "meshsize"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.float    "load"
    t.string   "length_unit",        default: "m"
    t.string   "width_unit",         default: "m"
    t.string   "height_unit",        default: "m"
    t.string   "meshsize_unit",      default: "m"
    t.string   "load_unit",          default: "n"
    t.string   "result_unit_system", default: "metric_mpa"
    t.integer  "material_id"
    t.integer  "job_id"
  end

  add_index "beams", ["job_id"], name: "index_beams_on_job_id"
  add_index "beams", ["material_id"], name: "index_beams_on_material_id"
  add_index "beams", ["name"], name: "index_beams_on_name", unique: true

  create_table "jobs", force: :cascade do |t|
    t.string   "pid"
    t.string   "jobdir"
    t.string   "status",     default: "Unsubmitted"
    t.string   "config",     default: "elmer"
    t.integer  "cores",      default: 1
    t.integer  "machines",   default: 1
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  create_table "materials", force: :cascade do |t|
    t.string   "name",         default: "Structural Steel"
    t.float    "modulus",      default: 200.0
    t.float    "poisson",      default: 0.3
    t.float    "density",      default: 7850.0
    t.string   "modulus_unit", default: "gpa"
    t.string   "density_unit", default: "kgm3"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.boolean  "deletable",    default: true
  end

end
