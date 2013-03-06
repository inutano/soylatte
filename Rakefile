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
      sh "rm -f ./*.dmp"
      sh "rm -f gc.prt"
      sh "rm -f readme.txt"
      sh "rm -f taxdump.tar.gz"
    end
  end
end

desc "About this Rakefile"
task :about do
  puts "Rakefile for setting up data and update"
end
