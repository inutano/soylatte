# :)

require 'parallel'
require 'stackprof'

require File.join(PROJ_ROOT, 'lib', 'soylattedb')

namespace :soylatte do
  db_dir = File.join(PROJ_ROOT, 'db')
  db = File.join(db_dir, 'soylatte.db')
  
  directory db_dir
  
  task :create_db => db
  file db => db_dir do |t|
    SoylatteDB::Scheme.up(t.name)
  end
  
  data_dir        = File.join(PROJ_ROOT, "data")
  accessions      = File.join(data_dir, "sra_metadata", "SRA_Accessions")
  live_accessions = File.join(data_dir, "live_accessions.list")
  
  file live_accessions => [data_dir, accessions] do |t|
    pattern = '$1 ~ /^.RP/ && $3 == "live" && $9 == "public"'
    sh "awk -F '\t' '#{pattern} { print $2 }' #{accessions} | sort -u > #{t.name}"
  end
  
  task :load_data => [ :load_references, :load_metadata, :load_publication ]
  
  task :load_references => db do |t|
    StackProf.run(mode: :cpu, raw: true, out: PROJ_ROOT + '/stackprof-cpu-load-reference.dump') do
      SoylatteDB::Reference.load(db)
    end
  end
  
  sub_id_list = open(live_accessions).read.split("\n")

  task :load_metadata => [db, live_accessions] do |t|
    StackProf.run(mode: :cpu, raw: true, out: PROJ_ROOT + '/stackprof-cpu-load-metadata.dump') do
      sub_id_list.each do |sub_id|
        SoylatteDB::SRA.new(db, sub_id).load
      end
    end
  end
  
  task :load_publication => [db, live_accessions] do |t|
    StackProf.run(mode: :cpu, raw: true, out: PROJ_ROOT + '/stackprof-cpu-load-publication.dump') do
      SoylatteDB::Publication.load(db)
    end
  end
end
