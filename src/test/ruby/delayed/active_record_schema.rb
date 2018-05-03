class ActiveRecord::Base
  db_file = 'src/test/resources/db/delayed.db'
  File.delete(db_file) if File.exist?(db_file)
  establish_connection :adapter => 'sqlite3', :database => db_file
  connection.create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority", :default => 0
    t.integer  "attempts", :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "cron" # plugin
  end
end
#ActiveRecord::Migration.verbose = false
#ActiveRecord::Schema.define(:version => 1) do
#  create_table "delayed_jobs", :force => true do |t|
#    t.integer  "priority", :default => 0
#    t.integer  "attempts", :default => 0
#    t.text     "handler"
#    t.text     "last_error"
#    t.datetime "run_at"
#    t.datetime "locked_at"
#    t.datetime "failed_at"
#    t.string   "locked_by"
#    t.string   "queue"
#    t.datetime "created_at", :null => false
#    t.datetime "updated_at", :null => false
#  end
#end