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
        table.uint16("pubmed_id", type: :vector)
        table.short_text("pmc_id", type: :vector)
        table.text("search_fulltext")
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
    acc_raw = `awk -F '\t' '$1 != "Accession" { print $1 "\t" $2 }' #{config["sra_accessions"]}`
    acc_raw.split("\n").each do |line|
      id_acc = line.split("\t")
      @@acc_hash[id_acc[0]] = id_acc[1]
    end
    
    @@run_hash = {} # runid => [ [expid, sampleid, studyid], .. ]
    @@study_hash = {} # studyid => runid
    run_raw = `awk -F '\t' '$1 != "Run" { print $1 "\t" $3 "\t" $4 "\t" $5 }' #{config["sra_run_members"]}`
    run_raw.split("\n").each do |line|
      id_acc = line.split("\t")
      @@run_hash[id_acc[0]] ||= []
      @@run_hash[id_acc[0]] << [id_acc[1], id_acc[2], id_acc[3]]
      @@study_hash[id_acc[3]] ||= []
      @@study_hash[id_acc[3]] << id_acc[0]
    end
    
    @@taxon_hash = {}
    taxon_raw = `awk -F ',' '{ print $1 "\t" $2 }' #{config["taxon_table"]}`
    taxon_raw.split("\n").each do |line|
      id_name = line.split("\t")
      @@taxon_hash[id_name[0]] = id_name[1]
    end
    
    @@pmc_hash = {}
    pmc_ids_raw = `awk -F ',' '{ print $10 "\t" $9 }' #{config["PMC-ids"]}`
    pmc_ids_raw.split("\n").each do |line|
      pmid_pmcid = line.split("\t")
      @@pmc_hash[pmid_pmcid[0]] = pmid_pmcid[1]
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
    acc_head = acc.slice(0..5)
    File.join(@@xml_base, acc_head, acc, acc + ".#{type}.xml")
  end
  
  def sample_insert
    submission_id = @@acc_hash[@id]
    xml = get_xml_path(@id, "sample")
    parser = SRAMetadataParser::Sample.new(@id, xml)
    sample_title = parser.title
    sample_description = parser.sample_description
    taxon_id = parser.taxon_id
    
    scientific_name = @@taxon_hash[taxon_id]
    
    { submission_id: submission_id,
      sample_title: sample_title,
      sample_description: clean_text(sample_description),
      taxon_id: taxon_id,
      scientific_name: scientific_name }
  rescue NameError, Errno::ENOENT
    { submission_id: submission_id }
  end
  
  def run_insert
    sample = @@run_hash[@id].map{|a| a[1] }.uniq
    submission_id = @@acc_hash[@id]
    experiment_id = @@run_hash[@id].map{|a| a[0] }.uniq.first
    
    xml = get_xml_path(experiment_id, "experiment")
    parser = SRAMetadataParser::Experiment.new(experiment_id, xml)
    
    { experiment_id: experiment_id,
      instrument: parser.instrument_model,
      library_strategy: parser.library_strategy,
      library_source: parser.library_source,
      library_selection: parser.library_selection,
      library_layout: parser.library_layout,
      library_orientation: parser.library_orientation,
      library_nominal_length: parser.library_nominal_length,
      library_nominal_sdev: parser.library_nominal_sdev,
      submission_id: submission_id,
      sample: sample }
  rescue NameError, Errno::ENOENT
    { experiment_id: experiment_id,
      submission_id: submission_id,
      sample: sample }
  end
  
  def project_insert
    run = @@study_hash[@id]

    submission_id = @@acc_hash[@id]
    pub_info = @@json.select{|row| submission_id == row["sra_id"] }
    pubmed_id = pub_info.map{|row| row["pmid"] }
    pmc_id = pubmed_id.map{|pmid| @@pmc_hash[pmid] }.uniq.compact
    
    xml = get_xml_path(@id, "study")
    parser = SRAMetadataParser::Study.new(@id, xml)
    study_title = parser.study_title
    study_type = parser.study_type

    { study_title: clean_text(study_title),
      study_type: study_type,
      run: run,
      submission_id: submission_id,
      pubmed_id: pubmed_id,
      pmc_id: pmc_id }
  rescue NameError, Errno::ENOENT
    { run: run,
      submission_id: submission_id,
      pubmed_id: pubmed_id,
      pmc_id: pmc_id }
  end
  
  def experiment_description
    xml = get_xml_path(@id, "experiment")
    parser = SRAMetadataParser::Experiment.new(@id, xml)

    array = [ parser.title,
              parser.design_description,
              parser.library_construction_protocol ]
    array.map{|d| clean_text(d) }.join("\s")
  rescue NameError, Errno::ENOENT
    nil
  end
  
  def project_description
    xml = get_xml_path(@id, "study")
    parser = SRAMetadataParser::Study.new(@id, xml)
    
    array = [ parser.center_name, 
              parser.center_project_name,
              parser.study_abstract,
              parser.study_description ]
    array.map{|d| clean_text(d) }.join("\s")
  rescue NameError, Errno::ENOENT
    nil
  end
   
  def pubmed_description
    if @id
      xml = open(@@eutil_base + "db=pubmed&id=#{@id}").read
      parser = PubMedMetadataParser.new(xml)
      
      array = [ @id.to_s,
                parser.journal_title,
                parser.article_title,
                parser.abstract,
                parser.affiliation,
                parser.authors.map{|n| n.values.compact },
                parser.chemicals.map{|n| n[:name_of_substance] },
                parser.mesh_terms.map{|n| n.values.compact } ]
      array.flatten.compact.map{|d| clean_text(d) }.join("\s")
    end
  end
  
  def bulk_pubmed_description
    xml = open(@@eutil_base + "db=pubmed&id=" + @id.join(",")).read
    id_text = Nokogiri::XML(xml).css("PubmedArticle").map{|n| n.to_xml }.map do |xml|
      parser = PubMedMetadataParser.new(xml)
      array = [ parser.journal_title,
                parser.article_title,
                parser.abstract,
                parser.affiliation,
                parser.authors.map{|n| n.values.compact },
                parser.chemicals.map{|n| n[:name_of_substance] },
                parser.mesh_terms.map{|n| n.values.compact } ]
      [parser.pmid, array.flatten.compact.map{|d| clean_text(d) }.join("\s")]
    end
    Hash[id_text.flatten]
  end
  
  def pmc_description
    xml = open(@@eutil_base + "db=pmc&id=#{@id}").read
    parser = PMCMetadataParser.new(xml)
    if parser.is_available?
      body = parser.body.compact.map do |section|
        if section.has_key?(:subsec)
          [section[:sec_title], section[:subsec].map{|subsec| subsec.values } ]
        else
          section.values
        end
      end
      
      ref_journal_list = parser.ref_journal_list
      title_ref_journal_list = ref_journal_list.map{|n| n.values } if ref_journal_list
    
      cited_by = parser.cited_by
      title_cited_by = cited_by.map{|n| n.values } if cited_by
    
      array = [ @id, body, title_ref_journal_list, title_cited_by ]
      array.flatten.compact.map{|d| clean_text(d) }.join("\s")
    end
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
