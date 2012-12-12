# -*- coding: utf-8 -*-

require "yaml"
require "open-uri"
require "json"
require "./sra_metadata_parser"
require "./pubmed_metadata_parser"
require "./pmc_metadata_parser"

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
  
  def initialize(id)
    @id = id
    @id_type = id.slice(2,1)
    @subid = case @id_type
             when "A"
               id
             else
               `grep #{id} #{@@accessions} | cut -f 2 | sort -u`.chomp
             end
    @xml_head = File.join(@@xmlbase, @subid.slice(0,6), @subid)
  end
  attr_accessor :subid
  
  def submission_parser
    xml = File.join(@xml_head, "#{@subid}.submission.xml")
    [SRAMetadataParser::Submission.new(@subid, xml)]
  rescue Errno::ENOENT, NameError
    nil
  end
  
  def study_parser
    studyid_arr = case @id_type
              when "P"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RP" | cut -f 1 | sort -u`.split("\n")
              when "R"
                `grep #{@id} #{@@run_members} | cut -f 5 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@accessions} | cut -f 13 | sort -u`.split("\n")
              end
    xml = File.join(@xml_head, "#{@subid}.study.xml")
    studyid_arr.select{|id| id =~ /^(S|E|D)RP\d{6}$/ }.map do |studyid|
      SRAMetadataParser::Study.new(studyid, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
  end
  
  def experiment_parser
    expid_arr = case @id_type
              when "X"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RX" | cut -f 1 | sort -u`.split("\n")
              when "R"
                `grep #{@id} #{@@run_members} | cut -f 3 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@accessions} | cut -f 11 | sort -u`.split("\n")
              end
    xml = File.join(@xml_head, "#{@subid}.experiment.xml")
    expid_arr.select{|id| id =~ /^(S|E|D)RX\d{6}$/ }.map do |expid|
      SRAMetadataParser::Experiment.new(expid, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
  end
  
  def sample_parser
    sampleid_arr = case @id_type
              when "S"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RS" | cut -f 1 | sort -u`.split("\n")
              when "R"
                `grep #{@id} #{@@run_members} | cut -f 4 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@accessions} | cut -f 12 | sort -u`.split("\n")
              end
    xml = File.join(@xml_head, "#{@subid}.sample.xml")
    sampleid_arr.select{|id| id =~ /^(S|E|D)RS\d{6}$/ }.map do |sampleid|
      SRAMetadataParser::Sample.new(sampleid, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
  end
  
  def run_parser
    runid_arr = case @id_type
              when "R"
                [@id]
              when "A"
                `grep #{@id} #{@@accessions} | grep "^.RR" | cut -f 1 | sort -u`.split("\n")
              else
                `grep #{@id} #{@@run_members} | cut -f 1 | sort -u`.split("\n")
              end
    xml = File.join(@xml_head, "#{@subid}.run.xml")
    runid_arr.select{|id| id =~ /^(S|E|D)RR\d{6}$/ }.map do |runid|
      SRAMetadataParser::Run.new(runid, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
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
  SRAParserGen.load_files("../lib/config.yaml")
  
  ids = ["DRR000001","DRR000010","DRR000020"]
  ids.each do |id|
    p = SRAParserGen.new(id)

    ap p.submission_parser
    ap p.study_parser
    ap p.experiment_parser
    ap p.sample_parser
    ap p.run_parser
    ap p.pubmed_parser
    ap p.pmc_parser
  end
end
