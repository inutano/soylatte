# -*- coding: utf-8 -*-

require "yaml"
require "nokogiri"
require File.expand_path(File.dirname(__FILE__)) + "/fastqc_result_parser"

class RunReport
  config_path = "/Users/inutano/project/soylatte/config.yaml"
  @@fastqc_path = YAML.load_file(config_path)["fqc_path"]
  
  def initialize(read_id)
    @read_id = read_id
    runid = @read_id.slice(0..8)
    head = runid.slice(0..5)
    fpath = File.join(@@fastqc_path, head, runid, @read_id + "_fastqc", "fastqc_data.txt")
    if File.exist?(fpath)
      @parser = FastQCParser.new(fpath)
    end
  end
  attr_reader :parser
  
  def report
     { read_id: @read_id,
       file_type: @parser.file_type,
       encoding: @parser.encoding,
       total_sequences: @parser.total_sequences,
       filtered_sequences: @parser.filtered_sequences,
       sequence_length: @parser.sequence_length,
       percent_gc: @parser.percent_gc,
       overrepresented_sequences: @parser.overrepresented_sequences,
       kmer_content: @parser.kmer_content }
  end
end
