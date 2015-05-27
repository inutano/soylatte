# :)

require File.join(PROJ_ROOT, 'lib', 'soylattedb.rb')

namespace :soylatte do
  db_dir = File.join(PROJ_ROOT, 'db')
  db = File.join(db_dir, 'project.db')
  
  directory db_dir
  
  task :create_db => db
  file db => db_dir do |t|
    SoylatteDB.up(t.name)
  end
  
  data_dir        = File.join(PROJ_ROOT, "data")
  accessions      = File.join(data_dir, "sra_metadata", "SRA_Accessions")
  live_accessions = File.join(data_dir, "live_accessions.list")
  
  task :load_data => [db, live_accessions] do |t|
    live_accessions.split("\n").each do |sub_id|
      SoylatteDB.load(sub_id)
    end
  end
  
  file live_accessions => [data_dir, accessions] do |t|
    pattern = '$1 ~ /^.RA/ && $3 == "live" && $9 == "public"'
    sh "awk -F '\t' '#{pattern} { print $1 }' #{accessions} > #{t.name}"
  end
end
