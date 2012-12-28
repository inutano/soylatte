# -*- coding: utf-8 -*-

require "open-uri"
require "yaml"
require File.expand_path(File.dirname(__FILE__)) + "/ebi_metadata_parser"

class ERAParserGen
  def initialize(id)
    @id = id
    @id_type = @id.slice(2,1)
  end
  
  def parser
    base_url = "http://www.ebi.ac.uk/ena/data/view/"
    xml = open(base_url + @id + "&display=xml").read
    case @id_type
    when "A"
      ERAMetadataParser::Submission.new(@id, xml)
    when "P"
      ERAMetadataParser::Study.new(@id, xml)
    when "X"
      ERAMetadataParser::Experiment.new(@id, xml)
    when "S"
      ERAMetadataParser::Sample.new(@id, xml)
    when "R"
      ERAMetadataParser::Run.new(@id, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
  end
  
  def load_files(config_path)
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
  
  def submission_id
    case @id_type
    when "A"
      id
    else
      `grep #{id} #{@@accessions} | cut -f 2 | sort -u`.chomp
    end
  end

  def submission_parser
    subid = self.submission_id
    url = "http://www.ebi.ac.uk/ena/data/view/#{subid}&display=xml"
    xml = open(url).read
    ERAMetadataParser::Submission.new(subid, xml)
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
    studyid_arr.select{|id| id =~ /^(S|E|D)RP\d{6}$/ }.map do |studyid|
      url = "http://www.ebi.ac.uk/ena/data/view/#{studyid}&display=xml"
      xml = open(url).read
      ERAMetadataParser::Study.new(studyid, xml)
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
    expid_arr.select{|id| id =~ /^(S|E|D)RX\d{6}$/ }.map do |expid|
      url = "http://www.ebi.ac.uk/ena/data/view/#{expid}&display=xml"
      xml = open(url).read
      ERAMetadataParser::Experiment.new(expid, xml)
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
    sampleid_arr.select{|id| id =~ /^(S|E|D)RS\d{6}$/ }.map do |sampleid|
      url = "http://www.ebi.ac.uk/ena/data/view/#{sampleid}&display=xml"
      xml = open(url).read
      ERAMetadataParser::Sample.new(sampleid, xml)
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
    runid_arr.select{|id| id =~ /^(S|E|D)RR\d{6}$/ }.map do |runid|
      url = "http://www.ebi.ac.uk/ena/data/view/#{runid}&display=xml"
      xml = open(url).read
      ERAMetadataParser::Run.new(runid, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
  end

  def pubmed_parser
    subid = self.submission_id
    pmid_arr = @@publication[subid.intern]
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
    subid = self.submission_id
    pmid_arr = @@publication[subid.intern]
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
  id = ARGV.first
  ap ERAParserGen.new(id).parser.all
end
