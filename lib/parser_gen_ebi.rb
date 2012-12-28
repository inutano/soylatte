# -*- coding: utf-8 -*-

require "open-uri"

class SRAParserGen
  def initialize(id)
    @id = id
  end
  
  def parser
    base_url = "http://www.ebi.ac.ul/ena/data/view/"
    xml = open(base_url + @id + "&display=xml").read
    case @id.slice(2,1)
    when "A"
      SRAMetadataParser::Submission.new(@id, xml)
    when "P"
      SRAMetadataParser::Study.new(@id, xml)
    when "X"
      SRAMetadataParser::Experiment.new(@id, xml)
    when "S"
      SRAMetadataParser::Sample.new(@id, xml)
    when "R"
      SRAMetadataParser::Run.new(@id, xml)
    end
  rescue Errno::ENOENT, NameError
    nil
  end
  
  def study_parser
  end
  
  def experiment_parser
  end
  
  def sample_parser
  end
  
  def run_parser
  end
end
