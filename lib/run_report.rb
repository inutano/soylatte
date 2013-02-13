# -*- coding: utf-8 -*-

require "yaml"
require "nokogiri"
require File.expand_path(File.dirname(__FILE__)) + "/fastqc_result_parser"

class RunReport
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    @@fastqc = config["fqc_path"]
  end
  
  def initialize(read_id)
    @read_id = read_id
    runid = @read_id.slice(0..8)
    head = runid.slice(0..5)
    fpath = File.join(@@fastqc, head, runid, @read_id + "_fastqc", "fastqc_data.txt")
    if File.exist?(fpath)
      @prsr = FastQCParser.new(fpath)
    end
  end
  
  def report
     { read_id: @read_id,
       file_type: @prsr.file_type,
       encoding: @prsr.encoding,
       total_sequences: @prsr.total_sequences,
       filtered_sequences: @prsr.filtered_sequences,
       sequence_length: @prsr.sequence_length,
       percent_gc: @prsr.percent_gc,
       overrepresented_sequences: @prsr.overrepresented_sequences,
       kmer_content: @prsr.kmer_content }
  end
end
