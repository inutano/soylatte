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
    @id_type = id.slice(2,1)
    @subid = case @id_type
             when "A"
               id
             when "P"
               @db.select{|r| r.project == id }.first.submission
             when "X"
               @db.select{|r| r.experiment == id }.first.submission
             when "S"
               @db.select{|r| r.sample == id }.first.submission
             when "R"
               @db.select{|r| r.key.key == id }.first.submission
             end
    @xml_head = File.join(@@xmlbase, @subid.slice(0,6), @subid)
  end
  attr_accessor :subid
  
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
                    @db.select{|r| r.submission == id }.map{|r| r.project }.uniq
                  when "X"
                    @db.select{|r| r.experiment == id }.map{|r| r.project }.uniq
                  when "S"
                    @db.select{|r| r.sample == id }.map{|r| r.project }.uniq
                  when "R"
                    @db.select{|r| r.key.key == id }.map{|r| r.project }.uniq
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
                  @db.select{|r| r.submission == id }.map{|r| r.experiment }.uniq
                when "P"
                  @db.select{|r| r.project == id }.map{|r| r.experiment }.uniq
                when "S"
                  @db.select{|r| r.sample == id }.map{|r| r.experiment }.uniq
                when "R"
                  @db.select{|r| r.key.key == id }.map{|r| r.experiment }.uniq
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
                     @db.select{|r| r.submission == id }.map{|r| r.sample }.uniq
                   when "P"
                     @db.select{|r| r.project == id }.map{|r| r.sample }.uniq
                   when "X"
                     @db.select{|r| r.experiment == id }.map{|r| r.sample }.uniq
                   when "R"
                     @db.select{|r| r.key.key == id }.map{|r| r.sample }.uniq
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
                when "S"
                  [@id]
                when "A"
                  @db.select{|r| r.submission == id }.map{|r| r.key.key }.uniq
                when "P"
                  @db.select{|r| r.project == id }.map{|r| r.key.key }.uniq
                when "X"
                  @db.select{|r| r.experiment == id }.map{|r| r.key.key }.uniq
                when "S"
                  @db.select{|r| r.sample == id }.map{|r| r.key.key }.uniq
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
  
  t0 = Time.now
  SRAParserGen.load_files("../lib/config.yaml")
  t00 = Time.now
  ap "loadfiles"
  ap t00 - t0
  
  ids = ["DRP000001","DRP000017","DRR000030"]
  ids.each do |id|
    
    
    t1 = Time.now
    p = SRAParserGen.new(id)
    ap "create object"
    ap t1 - t00

    t2 = Time.now
    ap p.submission_parser.class
    ap "submission"
    ap t2 - t1

    t3 = Time.now
    ap p.study_parser.class
    ap "study"
    ap t3 - t2

    t4 = Time.now
    ap p.experiment_parser.class
    ap "exp"
    ap t4 - t3

    t5 = Time.now
    ap p.sample_parser.class
    ap "sample"
    ap t5 - t4

    t6 = Time.now
    ap p.run_parser.class
    ap "run"
    ap t6 - t5

    t7 = Time.now
    ap p.pubmed_parser.class
    ap "pubmed"
    ap t7 - t6

    t8 = Time.now
    ap p.pmc_parser.class
    ap "pmc"
    ap t8 - t7
  end
end
