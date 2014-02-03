# -*- coding: utf-8 -*-

FileLoc = File.expand_path(File.dirname(__FILE__))

require "singleton"
require "yaml"
require "groonga"
require "open-uri"

require FileLoc + "/pubmed_metadata_parser"
require FileLoc + "/pmc_metadata_parser"
require FileLoc + "/fastqc_result_parser"

class Database
  include Singleton
  attr_reader :grndb
  
  config_path = File.join(FileLoc, "/../config.yaml")
  @@config = YAML.load_file(config_path)
  @@db_path = @@config["db_path"]
  
  def initialize
    connect_db
  end
  
  def connect_db
    if !@grndb || @grndb.closed?
      @grndb = Groonga::Database.open(@@db_path)
      @projects = self.projects
      @runs = self.runs
      @samples = self.samples
    end
  end
  
  def projects
    @projects ||= Groonga["Projects"]
  end

  def runs
    @runs ||= Groonga["Runs"]
  end

  def samples
    @samples ||= Groonga["Samples"]
  end
  
  def type
    @projects.map{|r| r.study_type }.uniq.compact.sort
  end

  def instruments
    @runs.map{|r| r.instrument }.uniq.compact.sort
  end
  
  def species
    @samples.map{|r| r.scientific_name }.uniq.compact
  end
    
  def projects_size
    @projects.size
  end

  def runs_size
    @runs.size
  end

  def samples_size
    @samples.size
  end

  def filter_species(species)
    if !species or species.empty?
      @projects.map{|r| r["_key"] }
    else
      @projects.select{|r| r.run.sample.scientific_name =~ species }.map{|r| r["_key"] }
    end
  end
  
  def filter_type(type) # type: Genome, etc.
    if !type or type.empty?
      @projects.map{|r| r["_key"] }
    else
      study_records = described_types[type].map do |study_type|
        @projects.select{|r| r.study_type == study_type }.map{|r| r["_key"] }
      end
      study_records.flatten.uniq
    end
  end
  
  def described_types
    { "Genome" => ["Whole Genome Sequencing","Resequencing","Population Genomics","Exome Sequencing"],
      "Transcriptome" => ["Transcriptome Analysis","RNASeq"],
      "Epigenome" => ["Epigenetics","Gene Regulation Study"],
      "Metagenome" => ["Metagenomics"],
      "Cancer Genomics" => ["Cancer Genomics"],
      "Other" => ["Other","Pooled Clone Sequencing","Forensic or Paleo-genomics","Synthetic Genomics"] }
  end
  
  def type_described?(type)
    described_types.has_key?(type)
  end
  
  def type_simple(type)
    # convert described types to simple categories by reversing described_types hash
    rev = {}
    described_types.each_pair do |k,v|
      v.each do |type|
        rev[type] = k
      end
    end
    rev[type]
  end
  
  def filter_instrument(instrument)
    if !instrument or instrument.empty?
      @projects.map{|r| r["_key"] }
    else
      @projects.select{|r| r.run.instrument =~ instrument }.map{|r| r["_key"] }
    end
  end
  
  def filter_result(species, type, instrument)
    filter_species = self.filter_species(species)
    filter_type = self.filter_type(type)
    filter_instrument = self.filter_instrument(instrument)
    mix = filter_species & filter_type & filter_instrument
    
    total = self.projects_size
    num_species = filter_species.size
    num_type = filter_type.size
    num_instrument = filter_instrument.size
    num_mix = mix.size
    
    ratio_species = ((num_species / total.to_f) * 100).round(2)
    ratio_type = ((num_type / total.to_f) * 100).round(2)
    ratio_instrument = ((num_instrument / total.to_f) * 100).round(2)
    ratio_mix = ((num_mix / total.to_f) * 100).round(2)
    
    { total: total,
      mix: { count: num_mix, ratio: ratio_mix },
      species: { count: num_species, ratio: ratio_species },
      type: { count: num_type, ratio: ratio_type },
      instrument: { count: num_instrument, ratio: ratio_instrument} }
  end
  
  def donuts_profile(species, type, instrument)
    h = self.filter_result(species, type, instrument)
    total = h[:total]

    hm = h[:mix]
    hmc = hm[:count]
    cond_m = { "Stat" => { "num" => hmc.to_s, "per" => hm[:ratio].to_s },
               "matched" => hmc.to_s,
               "unmatched" => (total - hmc).to_s }
    
    hs = h[:species]
    hsc = hs[:count]
    cond_s = { "Stat" => { "num" => hsc.to_s, "per" => hs[:ratio].to_s },
               "matched" => hsc.to_s,
               "unmatched" => (total - hsc).to_s }
    
    ht = h[:type]
    htc = ht[:count]
    cond_t = { "Stat" => { "num" => htc.to_s, "per" => ht[:ratio].to_s },
               "matched" => htc.to_s,
               "unmatched" => (total - htc).to_s }
    
    hi = h[:instrument]
    hic = hi[:count]
    cond_i = { "Stat" => { "num" => hic.to_s, "per" => hi[:ratio].to_s },
               "matched" => hic.to_s,
               "unmatched" => (total - hic).to_s }

    [cond_m, cond_s, cond_t, cond_i]
  end
  
  def filtered_records(condition)
    # return array of study id meets the condition
    filter_species = self.filter_species(condition[:species])
    filter_type = self.filter_type(condition[:type])
    filter_instrument = self.filter_instrument(condition[:instrument])
    filter_species & filter_type & filter_instrument
  end
  
  def search(query, condition)
    filtered = self.filtered_records(condition)
    if query
      if query.empty?
        filtered.map{|id| @projects[id] }
      else
        hit = @projects.select{|r| r.search_fulltext =~ query }.map{|r| r["_key"] }
        result = (hit & filtered).map{|id| @projects[id] }
        if !result.empty?
          result
        end
      end
    end
  end
  
  def search_api(query, condition)
    result = self.search(query, condition)
    if result
      result.map do |record|
        { study_id: record["_key"],
          study_title: record.study_title,
          study_type: record.study_type,
          experiment_id: record.run.map{|r| r.experiment_id }.uniq.compact,
          sequencing_instrument: record.run.map{|r| r.instrument }.uniq.compact,
          sample_id: record.run.map{|rr| rr.sample.map{|r| r["_key"] } }.flatten.uniq.compact,
          sample_organism: record.run.map{|rr| rr.sample.map{|r| r.scientific_name } }.flatten.uniq.compact,
          run_id: record.run.map{|r| r["_key"] }.uniq.compact,
          submission_id: record.submission_id,
          pubmed_id: record.pubmed_id,
          pmc_id: record.pmc_id }
      end
    end
  end
  
  def convert_to_study_record(id)
    case id.slice(2,1)
    when "P"
      id
    when "A"
      @projects.select{|r| r.submission_id =~ id }
    when "X"
      @projects.select{|r| r.run.experiment_id =~ id }
    when "S"
      @projects.select{|r| r.run.sample.key =~ id }
    when "R"
      @projects.select{|r| r.run.key =~ id }
    end
  end
  
  def convert_to_study_id(id)
    if id =~ /^.RP/
      id
    else
      record = self.convert_to_study_record(id)
      if record && record.size >= 1
        record.first["_key"]
      end
    end
  end
  
  def summary(study_id)
    p_record = @projects[study_id]
    r_record = p_record.run
    s_record = r_record.map{|r| r.sample }
    
    { study_id: study_id,
      study_title: p_record.study_title,
      type: p_record.study_type,
      species: s_record.map{|r| r.map{|s| s.scientific_name } }.flatten.uniq,
      instrument: r_record.map{|r| r.instrument }.uniq }
  end
  
  def paper(study_id)
    p_record = @projects[study_id]
    pmid_array = p_record.pubmed_id
    eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml"
    pmid_array.map do |pmid|
      arg = "&db=pubmed&id=#{pmid}"
      pm_parser = PubMedMetadataParser.new(open(eutil_base + arg).read)
      pmcid = pm_parser.pmcid
      { pubmed_id: pmid,
        journal: pm_parser.journal_title,
        title: pm_parser.article_title,
        abstract: pm_parser.abstract,
        affiliation: pm_parser.affiliation,
        authors: pm_parser.authors.map{|a| a.values.join("\s") },
        date: pm_parser.date_created.values.join("/"),
        pmc: self.pmc(pmcid) }
    end
  end
  
  def pmc(pmcid)
    if pmcid
      eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml"
      arg = "&db=pmc&id=#{pmcid}"
      pmc_parser = PMCMetadataParser.new(open(eutil_base + arg).read)
      body = pmc_parser.body.compact
      methods = body.select{|s| s[:sec_title] =~ /methods/i }
      results = body.select{|s| s[:sec_title] =~ /results/i }
      { pmc_id: pmcid,
        methods: methods,
        results: results,
        reference: pmc_parser.ref_journal_list,
        cited_by: pmc_parser.cited_by }
    end
  end
  
  def run_table(study_id)
    p_record = @projects[study_id]
    r_record = p_record.run
    r_record.map do |run|
      { run_id: run["_key"],
        experiment_id: run.experiment_id,
        submission_id: run.submission_id,
        sample_id: run.sample.map{|r| r["_key"] },
        study_type: p_record.study_type,
        instrument: run.instrument,
        lib_strategy: run.library_strategy,
        lib_source: run.library_source,
        lib_selection: run.library_selection,
        lib_layout: run.library_layout,
        lib_orientation: run.library_orientation,
        lib_nominal_length: run.library_nominal_length,
        lib_nominal_sdev: run.library_nominal_sdev,
        species: run.sample.map{|r| r.scientific_name }.uniq,
        read_profile: self.read_profile(run["_key"]) }
    end
  end
  
  def read_profile(run_id)
    path = File.join(@@config["fqc_path"], run_id.slice(0..5), run_id)
    Dir.entries(path).select{|f| f =~ /#{run_id}/ }.map do |read|
      data_path = File.join(path, read, "fastqc_data.txt")
      qc_parser = FastQCParser.new(data_path)
      { read_id: read.sub(/_fastqc$/,""),
        total_seq: qc_parser.total_sequences,
        seq_length: qc_parser.sequence_length }
    end
  rescue Errno::ENOENT
    nil
  end
  
  def sample_table(study_id)
    p_record = @projects[study_id]
    s_record = p_record.run.map{|r| r.sample.map{|s| s["_key"] }}
    s_record.flatten.uniq.map do |sid|
      { sample_id: sid,
        sample_description: @samples[sid].sample_description,
        run_id_list: @runs.select{|r| r.sample =~ sid }.map{|r| r["_key"] } }
    end
  end
  
  def project_report(study_id)
    { summary: self.summary(study_id),
      paper: self.paper(study_id),
      run_table: self.run_table(study_id),
      sample_table: self.sample_table(study_id) }
  end
  
  def run_report(read_id)
    run_id = read_id.slice(0..8)
    head = run_id.slice(0..5)
    fpath = File.join(@@config["fqc_path"], head, run_id, read_id + "_fastqc", "fastqc_data.txt")
    if File.exist?(fpath)
      parser = FastQCParser.new(fpath)
      { read_id: read_id,
        file_type: parser.file_type,
        encoding: parser.encoding,
        total_sequences: parser.total_sequences,
        filtered_sequences: parser.filtered_sequences,
        sequence_length: parser.sequence_length,
        percent_gc: parser.percent_gc,
        overrepresented_sequences: parser.overrepresented_sequences,
        kmer_content: parser.kmer_content }
    end
  end
  
  def download_link(subid, expid, runid)
    ddbj_base = "ftp://ftp.ddbj.nig.ac.jp/ddbj_database/dra"
    ebi_base = "ftp://ftp.sra.ebi.ac.uk/vol1/fastq"
    ncbi_base = "ftp://ftp-trace.ncbi.nlm.nih.gov/sra/sra-instant/reads/ByRun/sra"
    { dra_fastq: File.join(ddbj_base, "fastq", subid.slice(0..5), subid, expid),
      dra_sra: File.join(ddbj_base, "sralite/ByExp/litesra", expid.slice(0..2), expid.slice(0..5), expid),
      ena_fastq: File.join(ebi_base, runid.slice(0..5), runid),
      ncbi_sra: File.join(ncbi_base, runid.slice(0..2), runid.slice(0..5), runid) }
  end
  
  def export_run(id)
    run_table = self.run_table(id)
    result = run_table.map do |row|
      subid = row[:submission_id]
      expid = row[:experiment_id]
      runid = row[:run_id]
      hash = { sample_id: row[:sample_id],
               species: row[:species],
               instrument: row[:instrument],
               library_strategy: row[:lib_strategy],
               library_source: row[:lib_source],
               library_selection: row[:lib_selection],
               library_layout: row[:lib_layout],
               library_orientation: row[:lib_orientation],
               library_nominal_length: row[:lib_nominal_length],
               library_nominal_sdev: row[:lib_nominal_sdev],
               study_type: row[:study_type],
               experiment_id: expid,
               download: self.download_link(subid, expid, runid) }
      
      reads = row[:read_profile]
      if reads
        reads.map do |read|
          h = hash.dup
          h[:run_id] = read[:read_id]
          h[:total_seq] = read[:total_seq]
          h[:seq_length] = read[:seq_length]
          h
        end
      else
        hash[:run_id] = row[:run_id]
        hash
      end
    end
    result.flatten
  end

  def export_run_tsv(id)
    run_table = self.export_run(id)
    result = run_table.map do |row|
      [ row[:run_id],
        row[:sample_id].join(", "),
        row[:experiment_id],
        row[:study_type],
        row[:species].join(", "),
        row[:instrument],
        row[:library_strategy],
        row[:library_source],
        row[:library_selection],
        row[:library_layout],
        row[:library_orientation],
        row[:library_nominal_length],
        row[:library_nominal_sdev],
        row[:total_seq],
        row[:seq_length],
        row[:download][:dra_fastq],
        row[:download][:dra_sra],
        row[:download][:ena_fastq],
        row[:download][:ncbi_sra] ]
    end
    header = [ "Run ID",
               "Sample ID",
               "Experiment ID",
               "Study Type",
               "Sample Organism",
               "Sequencing Instrument",
               "Library Strategy",
               "Library Source",
               "Library Selection",
               "Library Layout",
               "Library Orientation",
               "Library Nominal Length",
               "Library Nominal Sdev",
               "Total Number of Sequence",
               "Sequence Length",
               "Download DDBJ/FASTQ",
               "Download DDBJ/SRA",
               "Download ENA/FASTQ",
               "Download NCBI/SRA" ]
    ([header] + result).map{|row| row.join("\t") }.join("\n")
  end
  
  def export_sample_tsv(id)
    table = self.sample_table(id)
    array = table.map do |row|
              [ row[:sample_id],
                row[:sample_description],
                row[:run_id_list].join(", ") ]
            end
    header = [ "Sample ID", "Sample Description", "Run ID"]
    ([header] + array).map{|row| row.join("\t") }.join("\n")
  end
  
  def data_retrieve(id, option)
    idtype = id.slice(2,1)
    dtype = option[:dtype]
    retmode = option[:retmode]
    case idtype
    when "P"
      case dtype
      when "run"
        case retmode
        when "json"
          JSON.dump(self.export_run(id))
        when "tsv"
          self.export_run_tsv(id)
        end
      when "sample"
        case retmode
        when "json"
          JSON.dump(self.sample_table(id))
        when "tsv"
          self.export_sample_tsv(id)
        end
      end
    end
  end
end

if __FILE__ == $0
  require "ap"
  db = Database.instance
  ap db.instruments
  ap db.species
  ap db.runs_size
  ap db.samples_size
  ap "filter: Homo sapiens, Transcriptome, Illumina Genome Analyzer"
  ap db.filter_result("Homo sapiens", "Transcriptome", "Illumina Genome Analyzer")
  
  query = ARGV.first
  if query =~ /(S|E|D)RP\d{6}/
    ap db.summary("DRP000001")
  elsif query
    ap ARGV.first + ", Homo sapiens, Transcriptome, Illumina GA"
    ap db.search(ARGV.first, species: "Homo sapiens", type: "Transcriptome", instrument: "Illumina Genome Analyzer")
  end
end
