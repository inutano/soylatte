# :)

require 'groonga'
require 'open-uri'

Groonga::Context.default_options = { encoding: :utf8 }

class SoylatteDB
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
      load_study_metadata(xml)
    when /experiment/
      load_experiment_metadata(xml)
    when /sample/
      load_sample_metadata(xml)
    when /run/
      load_run_metadata(xml)
    end
  end
  
  def load_study_metadata(xml)
  end
  
  def load_experiment_metadata(xml)
  end
  
  def load_sample_metadata(xml)
    sample_node_list = SRAMetadataParser::Sample.new(xml).parse
    sample_node_list.each do |node|
      insert_sample_record(node)
    end
  end
  
  def insert_sample_record(node)
    taxon_id = node[:organism_information][:taxon_id]
    scientific_name = Groonda["Taxon"][taxon_id].scientific_name
    Groonga["Samples"].add(
      node[:accession],
      submission_id:      @sub_id,
      sample_title:       node[:title],
      sample_description: node[:sample_description],
      taxon_id:           taxon_id,
      scientific_name:    scientific_name
    )
  end
  
  def load_run_metadata(xml)
  end

  def self.up(db_path)
    Groonga::Database.create(:path => db_path)
    
    Groonga::Schema.define do |schema|
      
      schema.create_table("Samples", :type => :hash) do |table|
        table.short_text("sample_title")
        table.text("sample_description")
        table.uint16("taxon_id")
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
