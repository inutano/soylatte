# :)

require 'groonga'
require 'open-uri'

Groonga::Context.default_options = { encoding: :utf8 }

class SoylatteDB
  class << self
    def load_references(db)
      establish_connection(db)
      load_studyids
      load_experiments
      load_taxons
    end
    
    def establish_connection(db)
      Groonga::Database.open(db)
    end

    def load_studyids
      publication_ref_pair = sra_publications_pair
      study_ids_pair.each_pair do |study_id, id_hash|
        run_id_list = id_hash[:run_id]
        sub_id_list = id_hash[:sub_id]
        
        pubmed_id_list = []
        pmc_id_list    = []
        sub_id_list.each do |sub_id|
          pubmed_id_list << publication_ref_pair[sub_id][:pubmed_id]
          pmc_id_list    << publication_ref_pair[sub_id][:pmc_id]
        end

        Groonga["StudyIDs"].add(
          study_id,
          run_id:    run_id_list,
          pubmed_id: pubmed_id_list,
          pmc_id:    pmc_id_list
        )
      end
    end
    
    def study_ids_pair
      pairs = Hash.new(Hash.new([]))
      accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
      cmd = "awk -F '\t' '$1 ~ /^.RR/ { OFS="\t" ; print $13, $1, $2 }' #{accessions}" # study_id, run_id, sub_id
      `#{cmd}`.split("\n").each do |ln|
        line = ln.split("\t")
        study_id = line[0]
        run_id   = line[1]
        sub_id   = line[2]

        pairs[study_id][:run_id] << run_id
        pairs[study_id][:sub_id] << sub_id
      end
      pairs
    end
    
    def sra_publications_pair
      publication_pair = pubmed_pmc_id_pair
      pairs = Hash.new(Hash.new([]))
      publication_json = File.join(PROJ_ROOT, "data", "publication.json")
      json = open(publication_json){|f| JSON.load(f) }
      json["ResultSet"]["Result"].each do |node|
        sub_id = node["sra_id"]
        pubmed_id = node["pmid"]
        pairs[sub_id][:pubmed_id] << pubmed_id
        pairs[sub_id][:pmc_id] << publication_pair[pubmed_id]
      end
      pairs
    end
    
    def pubmed_pmc_id_pair
      pairs = Hash.new("")
      pmc_ids = File.join(PROJ_ROOT, "data", "PMC-ids.csv")
      open(pmc_ids) do file
        while l = file.gets
          cols = l.split(",")
          pairs[cols[9]] = cols[8] # pubmed_id: pmc_id
        end
      end
      pairs
    end
    
    def load_experiments
      exp_run_id_pair.each_pair do |exp_id, run_id_list|
        Groonga["Experiments"].add(
          exp_id,
          run_id: run_id_list
        )
      end
    end
    
    def exp_run_id_pair
      pairs = Hash.new([])
      accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
      cmd = "awk -F '\t' '$1 ~ /^.RR/ { OFS="\t" ; print $11, $1 }' #{accessions}" # exp_id, run_id
      `#{cmd}`.split("\n").each do |ln|
        line = ln.split("\t")
        exp_id = line[0]
        run_id = line[1]
        pairs[exp_id] << run_id
      end
      pairs
    end
    
    def load_taxons
      taxon_table = File.join(PROJ_ROOT, "data", "taxon_table.csv")
      open(taxon_table) do |file|
        while lt = file.gets
          l = lt.split(",")
          taxon_id        = l[0]
          scientific_name = l[1]
          Groonga["Taxons"].add(
            taxon_id,
            scientific_name: scientific_name
          )
        end
      end
    end
  end
  
  def initialize(db, sub_id)
    @db = db
    @sub_id = sub_id
  end
  
  def load
    establish_connection
    [ :study, :experiment, :sample, :run ].each do |type|
      load_data(xml_path(@sub_id, type))
    end
  end
    
  def establish_connection
    Groonga::Database.open(@db)
  end
  
  def xml_path(type)
    base = File.join(PROJ_ROOT, "data", "sra_metadata")
    File.join(base, @sub_id.sub(/...$/,""), @sub_id, @sub_id + ".#{type}.xml")
  end
  
  def get_publication_xml
    base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&"
    pairs = { :pubmed => get_pubmed_id(@sub_id),
              :pmc    => get_pmc_id(@sub_id)     }
    pairs.each_pair do |type, ids|
      base + "db=#{type}&id=#{ids.join(",")}"
    end
  end
  
  def load_data(xml)
    case xml
    when /study/
      node_list = SRAMetadataParser::Study.new(xml).parse
      node_list.each do |node|
        insert_study_record(node)
      end
    when /experiment/
      node_list = SRAMetadataParser::Experiment.new(xml).parse
      node_list.each do |node|
        insert_experiment_record(node)
      end
    when /sample/
      node_list = SRAMetadataParser::Sample.new(xml).parse
      node_list.each do |node|
        insert_sample_record(node)
      end
    when /run/
      node_list = SRAMetadataParser::Run.new(xml).parse
      node_list.each do |node|
        insert_run_record(node)
      end
    end
  end
  
  def insert_study_record(node)
    study_id = node[:accession]
    
    study_id_record = Groonga["StudyIDs"][study_id]
    run_id_list    = study_id_record.run_id
    pubmed_id_list = study_id_record.pubmed_id
    pmc_id_list    = study_id_record.pmc_id
    
    Groonga["Projects"].add(
      study_id,
      submission_id: @sub_id,
      study_title:   node[:study_title],
      study_type:    node[:study_type],
      run:           run_id_list,
      pubmed_id:     pubmed_id_list,
      pmc_id:        pmc_id_list
    )
  end
  
  def insert_experiment_record(node)
    exp_id = node[:accession]
    run_id_list = Groonga["Experiments"][exp_id].run_id
    run_id_list.each do |run_id|
      Groonga["Runs"].add(
        run_id,
        submission_id: @sub_id,
        experiment_id: exp_id,
        sample: [node[:sample_accession]]),
        instrument:             node[:platform_information][:instrument],
        library_strategy:       node[:library_description][:library_strategy],
        library_source:         node[:library_description][:library_source],
        library_selection:      node[:library_description][:library_selection],
        library_layout:         node[:library_description][:library_layout],
        library_orientation:    node[:library_description][:library_orientation],
        library_nominal_length: node[:library_description][:library_nominal_length],
        library_nominal_sdev:   node[:library_description][:library_nominal_sdev]
      )
    end
  end
  
  def insert_sample_record(node)
    taxon_id = node[:organism_information][:taxon_id]
    scientific_name = Groonga["Taxons"][taxon_id].scientific_name
    Groonga["Samples"].add(
      node[:accession],
      submission_id:      @sub_id,
      taxon_id:           taxon_id,
      scientific_name:    scientific_name,
      sample_title:       node[:title],
      sample_description: node[:sample_description]
    )
  end
  
  ## scheme ##

  def self.up(db_path)
    Groonga::Database.create(:path => db_path)
    
    Groonga::Schema.define do |schema|
      schema.create_table("StudyIDs", :type => :hash) do |table|
        table.short_text("run_id", type: :vector)
        table.short_text("pubmed_id", type: :vector)
        table.short_text("pmc_id", type: :vector)
      end

      schema.create_table("Experiments", :type => :hash) do |table|
        table.short_text("run_id", type: :vector)
      end

      schema.create_table("Taxons", :type => :hash) do |table|
        table.short_text("scientific_name")
      end
      
      schema.create_table("Samples", :type => :hash) do |table|
        table.short_text("sample_title")
        table.text("sample_description")
        table.short_text("taxon_id")
        table.short_text("scientific_name")
        table.short_text("submission_id")
      end
      
      schema.create_table("Runs", type: :hash) do |table|
        table.short_text("experiment_id")
        table.short_text("library_strategy")
        table.short_text("library_source")
        table.short_text("library_selection")
        table.short_text("library_layout")
        table.short_text("library_orientation")
        table.short_text("library_nominal_length")
        table.short_text("library_nominal_sdev")
        table.short_text("instrument")
        table.short_text("submission_id")
        table.reference("sample", "Samples", type: :vector)
      end
      
      schema.create_table("Projects", type: :hash) do |table|
        table.short_text("study_title")
        table.short_text("study_type")
        table.reference("run", "Runs", type: :vector)
        table.short_text("submission_id", type: :vector)
        table.short_text("pubmed_id", type: :vector)
        table.short_text("pmc_id", type: :vector)
        table.long_text("search_fulltext")
      end
            
      schema.create_table("Index_text",
        type: :patricia_trie,
        key_normalize: true,
        default_tokenizer: "TokenBigram"
      )
      schema.change_table("Index_text") do |table|
        table.index("Samples.taxon_id")
        table.index("Samples.scientific_name")
        table.index("Runs.instrument")
        table.index("Runs.experiment_id")
        table.index("Projects.study_type")
        table.index("Projects.submission_id")
        table.index("Projects.pubmed_id")
        table.index("Projects.pmc_id")
        table.index("Projects.search_fulltext")
      end
      
      schema.change_table("Samples") do |table|
        table.index("Runs.sample")
      end

      schema.change_table("Runs") do |table|
        table.index("Projects.run")
      end
    end
  end
end
