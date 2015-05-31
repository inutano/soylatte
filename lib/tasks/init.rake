# :)

namespace :soylatte do
  data_dir     = File.join(PROJ_ROOT, "data")
  sra_metadata = File.join(data_dir, "sra_metadata")
  pmc_ids      = File.join(data_dir, "PMC-ids.csv")
  publication  = File.join(data_dir, "publication.json")
  taxon_table  = File.join(data_dir, "taxon_table.csv")
  
  directory data_dir
  
  task :fetch => [ :fetch_metadata, :fetch_scripts ]
  
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
    cd sra_metadata
    parent_dirs = Dir.entries(sra_metadata).select{|f| f =~ /^.RA\d+$/ }
    parent_dirs.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
      moveto = File.join sra_metadata, pid
      mkdir moveto
      mv ids, moveto
    end
  end

  file pmc_ids => data_dir do |t|
    base_url = "ftp://ftp.ncbi.nlm.nih.gov/pub/pmc"
    gzip     = "#{t.name}.gz"
    
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
    sh "lftp -c \"open #{base_url} && pget -n 8 -O #{tarball}\""
    sh "tar zxf #{tarball}"
    
    file = `grep "scientific" names.dmp`.gsub("|","\t").gsub(/\t/,",").split("\n")
    table = file.map{|l| l.split(",")[0..1].join(",") }
    open(t.name, "w"){|f| f.puts(array) }
    rm FileList["*.dmp"], "gc.prt", "readme.txt", tarball
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
      sh "git clone https://github.com/inutano/#{t.name.split("/").last} #{repos}"
    end
  end
  
  ## config ##
  
  log_dir  = File.join(PROJ_ROOT, "log")
  log_file = File.join(log_dir, "query.log")
  config_yaml = File.join(PROJ_ROOT, "config.yaml")
  
  directory log_dir

  task :config => [ log_file, config_yaml ]

  file log_file => log_dir do |t|
    touch t.name
  end

  file config_yaml => [log_dir, sra_metadata, pmc_ids, publication, taxon_table] do |t|
    paths = { 
              logfile: log_dir,
              sra_xml_base: sra_metadata,
              sra_accessions: File.join(sra_metadata, "SRA_Accessions"),
              sra_run_members: File.join(sra_metadata, "SRA_Run_Members"),
              pmc_ids: pmc_ids,
              publication: publication,
              taxon_table: taxon_table,
              fqc_path: File.join(data_dir, fastqc)
            }
    paths.each_pair do |name, path|
      sh "echo '#{name}: #{path}' >> #{t.name}"
    end
  end
end

