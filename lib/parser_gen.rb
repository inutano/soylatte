# -*- coding: utf-8 -*-

require "yaml"
require "open-uri"
require "json"
require "groonga"
require "#{File.expand_path(File.dirname(__FILE__))}/sra_metadata_parser"
require "#{File.expand_path(File.dirname(__FILE__))}/pubmed_metadata_parser"
require "#{File.expand_path(File.dirname(__FILE__))}/pmc_metadata_parser"

class SRAParserGen
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    file_path = config["file_path"]
    @@accessions = file_path["sra_accessions"]
    @@run_members = file_path["sra_run_members"]
    @@pmc_ids = file_path["PMC-ids"]
    @@xmlbase = file_path["xmlbase"]

    publication_url = file_path["publication"]
    publication_raw = open(publication_url).read
    publication_json = JSON.parse(publication_raw, :symbolize_names => true)
    @@publication = {}
    publication_json[:ResultSet][:Result].each do |node|
      @@publication[node[:sra_id].intern] ||= []
      @@publication[node[:sra_id].intern] << node[:pmid]
    end
  end
  
  def initialize(id, db)
    @id = id
    @db = db
    @id_type = @id.slice(2,1)
    @subid = case @id_type
             when "A"
               @id
             when "P"
               @db.select{|r| r.project == @id }.first.submission
             when "X"
               @db.select{|r| r.experiment == @id }.first.submission
             when "S"
               @db.select{|r| r.sample =~ @id }.first.submission
             when "R"
               @db[@id].submission
             end
    @xml_head = File.join(@@xmlbase, @subid.slice(0,6), @subid)
  end
  #attr_reader :subid
  
  def submission_parser
    xml = File.join(@xml_head, "#{@subid}.submission.xml")
    if File.exist?(xml)
      [SRAMetadataParser::Submission.new(@subid, xml)]
    end
  end
  
  def study_parser
    studyid_arr = case @id_type
                  when "P"
                    [@id]
                  when "A"
                    @db.select{|r| r.submission == @id }.map{|r| r.project }.uniq
                  when "X"
                    @db.select{|r| r.experiment == @id }.map{|r| r.project }.uniq
                  when "S"
                    @db.select{|r| r.sample =~ @id }.map{|r| r.project }.uniq
                  when "R"
                    [@db[@id].project]
                  end
    xml = File.join(@xml_head, "#{@subid}.study.xml")
    studyid_arr.map do |studyid|
      if File.exist?(xml)
        SRAMetadataParser::Study.new(studyid, xml)
      end
    end
  end
  
  def experiment_parser
    expid_arr = case @id_type
                when "X"
                  [@id]
                when "A"
                  @db.select{|r| r.submission == @id }.map{|r| r.experiment }.uniq
                when "P"
                  @db.select{|r| r.project == @id }.map{|r| r.experiment }.uniq
                when "S"
                  @db.select{|r| r.sample =~ @id }.map{|r| r.experiment }.uniq
                when "R"
                  [@db[@id].experiment]
                end
    xml = File.join(@xml_head, "#{@subid}.experiment.xml")
    expid_arr.map do |expid|
      if File.exist?(xml)
        SRAMetadataParser::Experiment.new(expid, xml)
      end
    end
  end
  
  def sample_parser
    sampleid_arr = case @id_type
                   when "S"
                     [@id]
                   when "A"
                     @db.select{|r| r.submission == @id }.map{|r| r.sample }.compact.map{|csv| csv.split(",") }.flatten.uniq
                   when "P"
                     @db.select{|r| r.project == @id }.map{|r| r.sample }.compact.map{|csv| csv.split(",") }.flatten.uniq
                   when "X"
                     @db.select{|r| r.experiment == @id }.map{|r| r.sample }.compact.map{|csv| csv.split(",") }.flatten.uniq
                   when "R"
                     [@db[@id].sample].compact.map{|csv| csv.split(",") }.flatten
                   end
    xml = File.join(@xml_head, "#{@subid}.sample.xml")
    sampleid_arr.map{|ids| ids.split(",") }.flatten.uniq.map do |sampleid|
      if File.exist?(xml)
        SRAMetadataParser::Sample.new(sampleid, xml)
      end
    end
  end
  
  def run_parser
    runid_arr = case @id_type
                when "R"
                  [@id]
                when "A"
                  @db.select{|r| r.submission == @id }.map{|r| r.key.key }.uniq
                when "P"
                  @db.select{|r| r.project == @id }.map{|r| r.key.key }.uniq
                when "X"
                  @db.select{|r| r.experiment == @id }.map{|r| r.key.key }.uniq
                when "S"
                  @db.select{|r| r.sample == @id }.map{|r| r.key.key }.uniq
                end
    xml = File.join(@xml_head, "#{@subid}.run.xml")
    runid_arr.map do |runid|
      if File.exist?(xml)
        SRAMetadataParser::Run.new(runid, xml)
      end
    end
  end
  
  def pubmed_parser
    pmid_arr = @@publication[@subid.intern]
    if pmid_arr
      pmid_arr.map do |pmid|
        eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?"
        arg = "db=pubmed&id=#{pmid}&retmode=xml"
        xml = open(eutil_base + arg).read
        PubMedMetadataParser.new(xml)
      end
    end
  end
  
  def pmc_parser
    pmid_arr = @@publication[@subid.intern]
    if pmid_arr
      pmid_arr.map do |pmid|
        pmcid = `grep #{pmid} #{@@pmc_ids}`.split(",")[8]
        if pmcid
          eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?"
          arg = "db=pmc&id=#{pmcid}&retmode=xml"
          xml = open(eutil_base + arg).read
          PMCMetadataParser.new(xml)
        end
      end
    end
  end
end

if __FILE__ == $0
  require "ap"
  
  SRAParserGen.load_files("../config.yaml")
  db_path = "./id_table_db/idtable.db"
  Groonga::Database.open(db_path)
  db = Groonga["IDtable"]

  #ids = ["DRP000001","DRP000017","DRR000030"]
  ids = ["ERP000115"]
  ids.each do |id|
    r = db.select{|r| r.project == id }
    ap id
    ap r.map{|r| r.submission }
    ap r.map{|r| r.experiment }
    ap r.map{|r| r.sample }
    ap r.map{|r| r.key.key }
    parser = SRAParserGen.new(id, db)
    ap parser.submission_parser
    ap parser.study_parser
    ap parser.experiment_parser
    ap parser.sample_parser
    ap parser.run_parser
    ap parser.pubmed_parser
    ap parser.pmc_parser
  end
end
