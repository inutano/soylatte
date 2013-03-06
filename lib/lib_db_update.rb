# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "open-uri"

require File.expand_path(File.dirname(__FILE__)) + "/sra_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pubmed_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pmc_metadata_parser"

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
        table.short_text("instrument")
        table.short_text("library_layout")
        table.short_text("library_orientation")
        table.short_text("library_nominal_length")
        table.short_text("library_nominal_sdev")
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
    
    @@accessions = config["sra_accessions"]
    @@run_members = config["sra_run_members"]
    @@xml_base = config["sra_xml_base"]
    @@taxon_table = config["taxon_table"]
    @@pmc_ids = config["PMC-ids"]
    
    publication = config["publication"]
    @@json = open(publication){|f| JSON.load(f) }["ResultSet"]["Result"]

    @@eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&"
  end
  
  def initialize(id)
    @id = id
  end
  
  def clean_text(text)
    text.delete("\t\n").gsub(/\s+/,"\s").chomp
  end
  
  def get_xml_path(id, type)
    acc = `grep -m 1 '^#{id}' #{@@accessions} | cut -f 2`.chomp
    raise NameError if acc !~ /^(S|E|D)RA\d{6}$/
    acc_head = acc.slice(0..5)
    File.join(@@xml_base, acc_head, acc, acc + ".#{type}.xml")
  rescue NameError
    ap @id
    ap id
    exit
  end
  
  def sample_insert
    submission_id = `grep -m 1 '^#{@id}' #{@@accessions} | cut -f 2 | sort -u`.chomp

    xml = get_xml_path(@id, "sample")
    parser = SRAMetadataParser::Sample.new(@id, xml)
    sample_title = parser.title
    sample_description = parser.sample_description
    taxon_id = parser.taxon_id
    
    scientific_name = `grep -m 1 '^#{taxon_id}' #{@@taxon_table} | cut -d ',' -f 2`.chomp
    
    { submission_id: submission_id,
      sample_title: sample_title,
      sample_description: clean_text(sample_description),
      taxon_id: taxon_id,
      scientific_name: scientific_name }
  rescue NameError, Errno::ENOENT
    { submission_id: submission_id }
  end
  
  def run_insert
    sample = `grep '^#{@id}' #{@@run_members} | cut -f 4 | sort -u`.split("\n")
    submission_id = `grep -m 1 '^#{@id}' #{@@accessions} | cut -f 2 | sort -u`.chomp

    experiment_id = `grep -m 1 '^#{@id}' #{@@run_members} | cut -f 3`.chomp
    xml = get_xml_path(experiment_id, "experiment")
    parser = SRAMetadataParser::Experiment.new(experiment_id, xml)
    
    { experiment_id: experiment_id,
      instrument: parser.instrument_model,
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
    xml = get_xml_path(@id, "study")
    parser = SRAMetadataParser::Study.new(@id, xml)
    study_title = parser.study_title
    study_type = parser.study_type
    
    run = `grep '#{@id}' #{@@run_members} | cut -f 1 | sort -u`.split("\n")
    
    submission_id = `grep '^#{@id}' #{@@accessions} | cut -f 2 | sort -u`.split("\n")
    
    pub_info = @@json.select{|row| submission_id.include?(row["sra_id"]) }
    pubmed_id = pub_info.map{|row| row["pmid"] }
    
    pmc_id_array = pubmed_id.map do |pmid|
      `grep -m 1 #{pmid} #{@@pmc_ids} | cut -d ',' -f 9`.chomp
    end
    pmc_id = pmc_id_array.uniq.compact
    
    { study_title: clean_text(study_title),
      study_type: study_type,
      run: run,
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
  end
  
  def pubmed_description
    if @id
      xml = open(@@eutil_base + "db=pubmed&id=#{@id}").read
      parser = PubMedMetadataParser.new(xml)
      
      array = [ @id,
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
  
  def pmc_description
    if @id
      xml = open(@@eutil_base + "db=pmc&id=#{@id}").read
      parser = PMCMetadataParser.new(xml)
      
      body = parser.body.compact.map do |section|
        if section.has_key?(:subsec)
          [section[:sec_title], section[:subsec].map{|subsec| subsec.values } ]
        else
          section.values
        end
      end
    
      array = [ @id,
                body,
                parser.ref_journal_list.map{|n| n.values },
                parser.cited_by.map{|n| n.values } ]
      array.flatten.compact.map{|d| clean_text(d) }.join("\s")
    end
  end
end
