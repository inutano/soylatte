# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "open-uri"
require "nokogiri"

DirPath = File.expand_path(File.dirname(__FILE__))

require DirPath + "/sra_metadata_parser"
require DirPath + "/pubmed_metadata_parser"
require DirPath + "/pmc_metadata_parser"

class DBupdate
  def self.create_db(db_path)
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

  def self.load_file(config_path)
    config = YAML.load_file(config_path)
    
    @@acc_hash = {} # any id => submissionid
    open(config["sra_accessions"]) do |file|
      while lt = file.gets
        l = lt.split("\t")
        @@acc_hash[l[0]] = l[1]
      end
    end
    
    @@run_hash = {} # runid => [ [expid, sampleid, studyid], .. ]
    @@study_hash = {} # studyid => runid
    open(config["sra_run_members"]) do |file|
      while lt = file.gets
        l = lt.split("\t")
        @@run_hash[l[0]] ||= []
        @@run_hash[l[0]] << [l[2], l[3], l[4]]
        @@study_hash[l[4]] ||= []
        @@study_hash[l[4]] << l[0]
      end
    end
    
    @@taxon_hash = {}
    open(config["taxon_table"]) do |file|
      while lt = file.gets
        l = lt.split(",")
        @@taxon_hash[l[0]] = l[1]
      end
    end
    
    @@pmc_hash = {} # pmid - pmcid
    open(config["PMC-ids"]) do |file|
      while lt = file.gets
        l = lt.split(",")
        @@pmc_hash[l[9]] = l[8]
      end
    end
    
    publication = config["publication"]
    @@json = open(publication){|f| JSON.load(f) }["ResultSet"]["Result"]
    
    @@xml_base = config["sra_xml_base"]
    @@eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&"
  end
  
  def initialize(id)
    @id = id
  end
  
  def clean_text(text)
    text.delete("\t\n").gsub(/\s+/,"\s").chomp
  end
  
  def get_xml_path(id, type)
    acc = @@acc_hash[id]
    path = File.join(@@xml_base, acc.sub(/...$/,""), acc, acc + ".#{type}.xml")
    path if File.exist?(path) && !(File.size(path) > 1_000_000)
  end
  
  def sample_insert
    # initialize insert hash
    insert = Hash.new("")
    
    # set submission id
    submission_id = @@acc_hash[@id]
    insert[:submission_id]      = submission_id
    
    # retrieve xml
    xml = get_xml_path(@id, "sample")
    if xml
      parser = SRAMetadataParser::Sample.new(@id, xml)

      # get scientific name
      taxon_id = parser.taxon_id
      scientific_name = @@taxon_hash[taxon_id]
    
      # set values
      insert[:sample_title]       = parser.title
      insert[:sample_description] = clean_text(parser.sample_description)
      insert[:taxon_id]           = taxon_id
      insert[:scientific_name]    = scientific_name
    end
    insert
  end
  
  def run_insert
    # initialize insert hash
    insert = Hash.new("")
    
    experiment_id = @@run_hash[@id].map{|a| a[0] }.uniq.first
    insert[:experiment_id] = experiment_id
    insert[:submission_id] = @@acc_hash[@id]
    insert[:sample]        = @@run_hash[@id].map{|a| a[1] }.uniq

    xml = get_xml_path(experiment_id, "experiment")
    if xml
      parser = SRAMetadataParser::Experiment.new(experiment_id, xml)
      insert[:instrument]             = parser.instrument_model
      insert[:library_strategy]       = parser.library_strategy
      insert[:library_source]         = parser.library_source
      insert[:library_selection]      = parser.library_selection
      insert[:library_layout]         = parser.library_layout
      insert[:library_orientation]    = parser.library_orientation
      insert[:library_nominal_length] = parser.library_nominal_length
      insert[:library_nominal_sdev]   = parser.library_nominal_sdev
    end
    insert
  end
  
  def project_insert
    # initialize insert hash
    insert = Hash.new("")
    
    # set id variables
    submission_id = @@acc_hash[@id]
    pub_info = @@json.select{|row| submission_id == row["sra_id"] }
    pubmed_id = pub_info.map{|row| row["pmid"] }
    pmc_id = pubmed_id.map{|pmid| @@pmc_hash[pmid] }.uniq.compact
    
    # set values
    insert[:run]           = @@study_hash[@id]
    insert[:submission_id] = submission_id
    insert[:pubmed_id]     = pubmed_id
    insert[:pmc_id]        = pmc_id
    
    # parse xml
    xml = get_xml_path(@id, "study")
    if xml
      parser = SRAMetadataParser::Study.new(@id, xml)
      insert[:study_title]   = clean_text(parser.study_title)
      insert[:study_type]    = parser.study_type
    end
    insert
  end
  
  def experiment_description
    desc_array = []
    xml = get_xml_path(@id, "experiment")
    if xml
      parser = SRAMetadataParser::Experiment.new(@id, xml)
      desc_array << parser.title
      desc_array << parser.design_description
      desc_array << parser.library_construction_protocol
    end
    clean_text(desc_array.join("\s"))
  end
  
  def project_description
    desc_array = []
    xml = get_xml_path(@id, "study")
    if xml
      parser = SRAMetadataParser::Study.new(@id, xml)
      desc_array << parser.center_name
      desc_array << parser.center_project_name
      desc_array << parser.study_abstract
      desc_array << parser.study_description
    end
    clean_text(desc_array.join("\s"))
  end
  
  def bulk_retrieve
    idlist = @id.join(",")
    if idlist =~ /PMC/
      bulkpmc_parse(bulk_xml(idlist, :pmc))
    else
      bulkpubmed_parse(bulk_xml(idlist, :pubmed))
    end
  end
  
  def bulk_xml(idlist, sym)
    open(@@eutil_base + "db=" + sym.to_s + "&id=" + idlist).read
  end
  
  def bulkpmc_parse(xml)
    pmcid_text = Hash.new("")
    Nokogiri::XML(xml).css("article").each do |article|
      p = PMCMetadataParser.new(article.to_xml)
      ref_journal_list = p.ref_journal_list || []
      cited_by         = p.cited_by || []
      
      text = []
      text << ref_journal_list.map{|n| n.values }
      text << cited_by.map{|n| n.values }
      text << pmc_body_text(p)
      
      # set key/pmcid, value/text
      pmcid_text["PMC" + p.pmcid] = clean_text(text.join("\s"))
    end
    pmcid_text
  rescue Errno::ENETUNREACH
    sleep 180
    retry
  end
  
  def pmc_body_text(pmc_parser)
    pmc_parser.body.compact.map do |section|
      if section.has_key?(:subsec)
        [section[:sec_title], section[:subsec].map{|subsec| subsec.values }]
      else
        section.values
      end
    end
  end
  
  def bulkpubmed_parse(xml)
    pmid_text = Hash.new("")
    Nokogiri::XML(xml).css("PubmedArticle").each do |article|
      p = PubMedMetadataParser.new(article.to_xml)
      text = []
      text << p.journal_title
      text << p.article_title
      text << p.abstract
      text << p.affiliation
      text << p.authors.map{|n| n.values.compact }
      text << p.chemicals.map{|n| n[:name_of_substance] }
      text << p.mesh_terms.map{|n| n.values.compact }
      pmid_text[p.pmid] = clean_text(text.join("\s"))
    end
    pmid_text
  rescue Errno::ENETUNREACH
    sleep 180
    retry
  end
end

if __FILE__ == $0
  require "ap"
  ap "start loading file #{Time.now}"
  DBupdate.load_file("../config.yaml")
  ap "finish loading file #{Time.now}"
  id = "ERR013086"
  ap DBupdate.new(id).run_insert
end
