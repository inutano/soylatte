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
        @@run_hash[l[0]] << [l[1], l[2], l[3]]
        @@study_hash[l[3]] ||= []
        @@study_hash[l[3]] << l[0]
      end
    end
    
    @@taxon_hash = {}
    open(config["taxon_table"]) do |file|
      while lt = file.gets
        l = lt.split("\t")
        @@taxon_hash[l[0]] = l[1]
      end
    end
    
    @@pmc_hash = {} # pmid - pmcid
    open(config["PMC-ids"]) do |file|
      while lt = file.gets
        l = lt.split("\t")
        @@pmc_hash[l[0]] = l[1]
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
    acc_head = acc.slice(0..5)
    File.join(@@xml_base, acc_head, acc, acc + ".#{type}.xml")
  end
  
  def sample_insert
    submission_id = @@acc_hash[@id]
    xml = get_xml_path(@id, "sample")
    raise NameError if File.size(xml) > 1_000_000
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
    raise NameError if File.size(xml) > 1_000_000
    
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
    raise NameError if File.size(xml) > 1_000_000
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
    raise NameError if File.size(xml) > 1_000_000
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
    raise NameError if File.size(xml) > 1_000_000
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
      puts @@eutil_base + "db=pubmed&id=#{@id}"
      sleep 1
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
  
  def bulk_retrieve
    idlist = @id.join(",")
    if idlist =~ /PMC/
      bulk_parse(idlist, :pmc)
    else
      bulk_parse(idlist, :pubmed)
    end
  end
  
  def bulk_parse(idlist, sym)
    xml = bulk_xml(idlist, sym)
    case sym
    when :pmc
      bulkpmc_parse(xml)
    when :pubmed
      bulkpubmed_parse(xml)
    end
  end
  
  def bulk_xml(idlist, sym)
    open(@@eutil_base + "db=" + sym.to_s + "&id=" + idlist).read
  end
  
  def bulkpmc_parse(xml)
    pmcid_text = Nokogiri::XML(xml).css("article").map{|n| n.to_xml }.map do |xml|
      p = PMCMetadataParser.new(xml)
      if p.is_available?
        # article body
        body = p.body.compact.map do |section|
          if section.has_key?(:subsec)
            [section[:sec_title], section[:subsec].map{|subsec| subsec.values } ]
          else
            section.values
          end
        end
        # metadata
        ref_journal_list = p.ref_journal_list
        title_ref_journal_list = ref_journal_list.map{|n| n.values } if ref_journal_list
        cited_by = p.cited_by
        title_cited_by = cited_by.map{|n| n.values } if cited_by
        # merge
        array = [body, title_ref_journal_list, title_cited_by]
        [ p.pmid, array.flatten.compact.map{|d| clean_text(d) }.join("\s") ]
      end
    end
    array_to_hash(pmcid_text)
  rescue Errno::ENETUNREACH
    sleep 300
    retry
  end
  
  def bulkpubmed_parse(xml)
    pmid_text = Nokogiri::XML(xml).css("PubmedArticle").map{|n| n.to_xml }.map do |xml|
      p = PubMedMetadataParser.new(xml)
      array = [ p.journal_title,
                p.article_title,
                p.abstract,
                p.affiliation,
                p.authors.map{|n| n.values.compact },
                p.chemicals.map{|n| n[:name_of_substance] },
                p.mesh_terms.map{|n| n.values.compact } ]
      [ p.pmid, array.flatten.compact.map{|d| clean_text(d) }.join("\s") ]
    end
    array_to_hash(pmid_text)
  rescue Errno::ENETUNREACH
    sleep 300
    retry
  end
  
  def array_to_hash(array)
    h = {}
    array.each do |k_v|
      key = k_v.first
      value = k_v.last
      h[key] = value
    end
    h
  end
  
  # test implementation; not tested
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
    Hash[id_text.flatten] ## NO LONGER WORK WITH < RUBY 2.0
  end
  
  def pmc_description
    puts @@eutil_base + "db=pmc&id=#{@id}"
    sleep 1
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
