# -*- coding: utf-8 -*-

task :default => :about

namespace :setup do
  desc "Setting up files and directories"
  task :init => ["log/query.log", :get_files] do
    puts "Done."
    puts "You will need:"
    puts "- rake setup:config"
    puts "- updating groonga database"
    puts "- place fastqc results"
  end
  
  directory "log"
  
  desc "Create empty logfile"
  file "log/query.log" => "log" do |t|
    sh "touch #{t.name}"
  end
  
  task :get_files => ["SRA_Accessions.tab","SRA_Run_Members.tab", "PMC-ids.csv", "publication.json", "taxon_table.csv"]
  
  directory "data"
  
  desc "Download SRA metadata table"
  rule %r{SRA.+\.tab}  => "data" do |t|
    unless File.exist? File.join("data", t.name)
      base_url = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
      `lftp -c "open #{base_url} && pget -n 8 #{t.name}"`
      mv t.name, "data"
    end
  end
  
  desc "Download PMC id table"
  file "PMC-ids.csv" => "data" do |t|
    unless File.exist? File.join("data", t.name)
      base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/pmc"
      `lftp -c "open #{base_url} && pget -n 8 #{t.name}.gz"`
      sh "gunzip #{t.name}.gz"
      mv t.name, "data"
    end
  end
  
  desc "Download SRA-Publication list"
  file "publication.json" => "data" do |t|
    unless File.exist? File.join("data", t.name)
      url = "http://sra.dbcls.jp/cgi-bin/publication2.php"
      sh "wget #{url}"
      mv "publication2.php", "data/#{t.name}"
    end
  end
  
  desc "Download taxonomy id <=> scientific name table"
  file "taxon_table.csv" => "data" do |t|
    unless File.exist? File.join("data", t.name)
      base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy"
      `lftp -c "open #{base_url} && pget -n 8 taxdump.tar.gz"`
      sh "tar zxfv taxdump.tar.gz"
      
      file = `grep "scientific" names.dmp`.gsub("|","\t").gsub(/\t+/,",").split("\n")
      array = file.map{|l| l.split(",")[0..1].join(",") }
      open(t.name,"w"){|f| f.puts(array) }
      mv t.name, "data"
      rm "./*.dmp"
      rm "gc.prt"
      rm "readme.txt"
      rm "taxdump.tar.gz"
    end
  end
  
  desc "Create configuration file"
  task :config => "config.yaml" do
    puts "Done."
  end
  
  desc "Create config.yaml"
  file "config.yaml" do |t|
    dir = File.expand_path(File.dirname(__FILE__))
    sh "echo 'logfile: \"#{dir}/log/query.log\"' >> #{t.name}"
    sh "echo 'db_path: \"#{dir}/db/project.db\"' >> #{t.name}"
    sh "echo 'sra_accessions: \"#{dir}/data/SRA_Accessions.tab\"' >> #{t.name}"
    sh "echo 'sra_run_members: \"#{dir}/data/SRA_Run_Members.tab\"' >> #{t.name}"
    sh "echo 'PMC-ids: \"#{dir}/data/PMC-ids.csv\"' >> #{t.name}"
    sh "echo 'sra_xml_base: \"#{dir}/data/metadata_xml\"' >> #{t.name}"
    sh "echo 'publication: \"#{dir}/data/publication.json\"' >> #{t.name}"
    sh "echo 'taxon_table: \"#{dir}/data/taxon_table.csv\"' >> #{t.name}"
    sh "echo 'fqc_path: \"#{dir}/data/fastqc\"' >> #{t.name}"
  end
end

namespace :update do
  desc "Replace files for updating DB."
  task :init => :replace_files do
    puts "finished."
    puts "You will need:"
    puts "ruby ./lib/db_update.rb"
  end
  
  task :replace_files => ["SRA_Accessions.tab","SRA_Run_Members.tab", "PMC-ids.csv", "publication.json", "taxon_table.csv"]
  
  directory "data/prev"
  
  today = "_" + Time.now.strftime("%m%d")
  
  desc "Download SRA metadata table"
  rule %r{SRA.+\.tab}  => "data/prev" do |t|
    mv File.join("data", t.name), File.join("data/prev", t.name + today)
    base_url = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
    `lftp -c "open #{base_url} && pget -n 8 #{t.name}"`
    mv t.name, "data"
  end
  
  desc "Download PMC id table"
  file "PMC-ids.csv" => "data/prev" do |t|
    mv File.join("data", t.name), File.join("data/prev", t.name + today)
    base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/pmc"
    `lftp -c "open #{base_url} && pget -n 8 #{t.name}.gz"`
    sh "gunzip #{t.name}.gz"
    mv t.name, "data"
  end
  
  desc "Download SRA-Publication list"
  file "publication.json" => "data/prev" do |t|
    mv File.join("data", t.name), File.join("data/prev", t.name + today)
    url = "http://sra.dbcls.jp/cgi-bin/publication2.php"
    sh "wget #{url}"
    mv "publication2.php", "data/#{t.name}"
  end
  
  desc "Download taxonomy id <=> scientific name table"
  file "taxon_table.csv" => "data/prev" do |t|
    mv File.join("data", t.name), File.join("data/prev", t.name + today)
    base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy"
    `lftp -c "open #{base_url} && pget -n 8 taxdump.tar.gz"`
    sh "tar zxfv taxdump.tar.gz"
      
    file = `grep "scientific" names.dmp`.gsub("|","\t").gsub(/\t+/,",").split("\n")
    array = file.map{|l| l.split(",")[0..1].join(",") }
    open(t.name,"w"){|f| f.puts(array) }
    mv t.name, "data"
    rm "./*.dmp"
    rm "gc.prt"
    rm "readme.txt"
    rm "taxdump.tar.gz"
  end
end

desc "About this Rakefile"
task :about do
  puts "Rakefile for setting up data and update"
end
