# :)

namespace :soylatte do
  data_dir     = File.join(PROJ_ROOT, "data")
  sra_metadata = File.join(data_dir, "sra_metadata")
  pmc_ids      = File.join(data_dir, "PMC-ids.csv")
  publication  = File.join(data_dir, "publication.json")
  taxon_table  = File.join(data_dir, "taxon_table.csv")
  
  directory data_dir
  
  task :fetch => [ :fetch_metadata, :fetch_scripts ] do
    puts "fetch metadata and scripts: done."
  end
  
  ## fetch metadata ##
  
  task :fetch_metadata => [ sra_metadata, :fix_metadata_dir, pmc_ids, publication, taxon_table ]
  
  file sra_metadata => data_dir do |t|
    base_url = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
    metadata = "NCBI_SRA_Metadata_Full_#{Time.now.strftime("%Y%m")}01"
    tarball  = metadata + ".tar.gz"
    tarball_path = File.join(data_dir, tarball)
    
    cd data_dir
    sh "lftp -c \"open #{base_url} && pget -n 8 -O #{data_dir} #{tarball}\""
    sh "tar zxf #{tarball_path}"
    mv metadata, t.name
    rm tarball_path
  end
  
  task :fix_metadata_dir => sra_metadata do |t|
    original_files = Dir.entries(sra_metadata).select{|f| f =~ /^.RA\d+$/ }
    if !original_files.select{|f| f =~ /^.RA\d{6,7}/ }.empty? # check if it's done
      cd sra_metadata
      original_files.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
        moveto = File.join sra_metadata, pid
        mkdir moveto
        mv ids, moveto
      end
    end
  end

  file pmc_ids => data_dir do |t|
    base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/pmc"
    gzip     = "#{t.name.split("/").last}.gz"
    
    cd data_dir
    sh "lftp -c \"open #{base_url} && pget -n 8 -O #{data_dir} #{gzip}\""
    sh "gunzip #{gzip}"
  end
  
  file publication => data_dir do |t|
    base_url  = "http://sra.dbcls.jp/cgi-bin"
    fname_raw = "publication2.php"
    cd data_dir
    sh "wget #{base_url}/#{fname_raw}"
    mv fname_raw, t.name
  end
  
  file taxon_table => data_dir do |t|
    base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy"
    tarball  = "taxdump.tar.gz"
    
    cd data_dir
    sh "lftp -c \"open #{base_url} && pget -n 8 #{tarball}\""
    sh "tar zxf #{tarball}"
    
    file = `grep "scientific" names.dmp`.gsub("|","\t").gsub(/\t/,",").split("\n")
    table = file.map{|l| l.split(",")[0..1].join(",") }
    open(t.name, "w"){|f| f.puts(table) }
    rm [FileList["*.dmp"], "gc.prt", "readme.txt", tarball].flatten
  end
  
  ## fetch scripts ##
  
  lib_dir       = File.join(PROJ_ROOT, "lib")
  repos = File.join(lib_dir, "repos")
  sra_metadata_toolkit = File.join(repos, "sra_metadata_toolkit")
  pmc_metadata_toolkit = File.join(repos, "opPMC")

  directory lib_dir
  directory repos
  
  task :fetch_scripts => [ sra_metadata_toolkit, pmc_metadata_toolkit ]
  
  [sra_metadata_toolkit, pmc_metadata_toolkit].each do |fpath|
    file fpath => repos do |t|
      cd repos
      sh "git clone https://github.com/inutano/#{t.name.split("/").last}"
    end
  end
  
  ## config ##
  
  log_dir  = File.join(PROJ_ROOT, "log")
  log_file = File.join(log_dir, "query.log")
  
  fastqc_dir = File.join(data_dir, "fastqc")

  public_dir = File.join(PROJ_ROOT, "public")

  directory log_dir
  directory fastqc_dir
  directory public_dir

  task :config => [log_file, fastqc_dir, public_dir] do
    puts "repository configuration: done."
  end

  file log_file => log_dir do |t|
    touch t.name
  end
end

