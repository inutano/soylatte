# :)

require 'groonga'
require File.join(PROJ_ROOT, 'lib', 'repos', 'sra_metadata_toolkit', 'fastqc_utils')
require File.join(PROJ_ROOT, 'lib', 'repos', 'opPMC', 'publication_metadata_parser')

class Array
  def minimize
    self.flatten.uniq.compact.sort
  end
end

class SoylatteDB
  class Base
    class << self
      include FastQC

      def projectdb
        Groonga["Projects"]
      end

      def rundb
        Groonga["Runs"]
      end

      def sampledb
        Groonga["Samples"]
      end

      ### core ###

      ## category values list ##

      def keys(records)
        records.map{|r| r["_key"] }
      end

      def study_type_list
        list(projectdb, :study_type)
      end

      def instrument_list
        list(rundb, :instrument)
      end

      def organism_list
        list(sampledb, :scientific_name)
      end

      def list(db, sym)
        db.map{|r| r.send(sym) }.minimize
      end

      ## filtering records ##

      def filter_records_by(sym, query)
        case sym
        when :species
          filter_species(query)
        when :study_type
          filter_study_type(query)
        when :instrument
          filter_instrument(query)
        end
      end

      def filter_species(species)
        filter(projectdb, [ :run, :sample, :scientific_name ], species)
      end

      def filter_study_type(type)
        filtered_sets = described_types[type].map do |described_type|
          filter_described_type(described_type)
        end
        filtered_sets.flatten.uniq
      end

      def filter_described_type(described_type)
        filter(projectdb, [ :study_type ], described_type)
      end

      def filter_instrument(instrument)
        filter(projectdb, [ :run, :instrument ], instrument)
      end

      def filter(db, syms, keyword)
        if !keyword or keyword.empty?
          db
        else
          select(db, syms, keyword)
        end
      end

      def select(db, syms, keyword)
        db.select{|r| syms.inject(r, :send) =~ keyword }
      end

      ## Search Core ##

      def soylatte_faceted_search(options)
        facets = [ :species, :study_type, :instrument ]
        matched_records = facets.map{|sym| filter_by(sym, options[sym]) }.inject(:&)
        search_fulltext(matched_records, options[:keyword])
      end

      def search_fulltext(records, keyword)
        if !keyword or keyword.empty?
          records
        else
          records.select{|r| r.search_fulltext =~ keyword }
        end
      end

      ## dictionary for simplified study type ##

      def described_types
        { "Genome"          => [
                                 "Whole Genome Sequencing",
                                 "Resequencing",
                                 "Population Genomics",
                                 "Exome Sequencing"
                               ],
          "Transcriptome"   => [
                                 "Transcriptome Analysis",
                                 "RNASeq"
                               ],
          "Epigenome"       => [
                                 "Epigenetics",
                                 "Gene Regulation Study"
                               ],
          "Metagenome"      => [
                                 "Metagenomics"
                               ],
          "Cancer Genomics" => [
                                 "Cancer Genomics"
                               ],
          "Other"           => [
                                 "Other",
                                 "Pooled Clone Sequencing",
                                 "Forensic or Paleo-genomics",
                                 "Synthetic Genomics"
                               ]
        }
      end

      def type_simple(type)
        study_type_simplified(type)
      end

      def study_type_simplified(type)
        described_types.select{|k,v| v.include?(type) }.keys[0]
      end

      def type_described?(type)
        described_types.has_key?(type)
      end


      ### Methods for backward compatibility ###

      def type
        study_type_list
      end

      def instruments
        instrument_list
      end

      def species
        organism_list
      end

      def projects_size
        projectdb.size
      end

      def runs_size
        rundb.size
      end

      def samples_size
        sampledb.size
      end

      # species: scientific name like 'Homo sapiens'
      def filter_species(species)
        get_study_id_by(:species, species)
      end

      def filter_type(study_type)
        get_study_id_by(:study_type, study_type)
      end

      def filter_instrument(instrument)
        get_study_id_by(:instrument, instrument)
      end

      def get_study_id_by(sym, query)
        records = filter_records_by(sym, query)
        keys(records)
      end

      def filter_type(type)
        filter_study_type(type)
      end

      def filter_result(species, study_type, instrument)
        options = { species: species, study_type: study_type, instrument: instrument }
        {
          total:      projectdb.size,
          mix:        count_and_ratio(soylatte_faceted_search(options)),
          species:    count_and_ratio(filter_by(:species, species)),
          type:       count_and_ratio(filter_by(:study_type, type)),
          instrument: count_and_ratio(filter_by(:instrument, instrument))
        }
      end

      def count_and_ratio(records)
        rs = records.size
        {
          count: rs,
          ratio: ((rs / projectdb.size.to_f) * 100).round(2)
        }
      end

      def donuts_profile(species, study_type, instrument)
        counts_and_ratios = filter_result(species, study_type, instrument)
        [ :mix, :species, :study_type, :instrument ].map do |sym|
          donuts_stat(counts_and_ratios[sym])
        end
      end

      def donuts_stat(c_r)
        c = c_r[:count]
        r = c_r[:ratio]
        {
          "Stat" => {
                      "num" => "#{c}",
                      "per" => "#{r}"
                    },
          "matched"   => "#{c}",
          "unmatched" => "#{projectdb.size - c}"
        }
      end

      def filtered_records(options)
        options[:study_type] = options[:type]
        keys(soylatte_faceted_search(options))
      end

      def search(keyword, options)
        if keyword
          options[:study_type] = options[:type]
          options[:keyword]    = keyword
          soylatte_faceted_seearch(options)
        end
      end

      ## experimental

      def related_runs(study_record)
        study_record.run
      end

      def run_full_detail(record)
        {
          run_id:             record["_key"],
          experiment_id:      record.experiment_id,
          instrument:         record.instrument,
          lib_strategy:       record.library_strategy,
          lib_source:         record.library_source,
          lib_selection:      record.library_selection,
          lib_layout:         record.library_layout,
          lib_orientation:    record.library_orientation,
          lib_nominal_length: record.library_nominal_length,
          lib_nominal_sdev:   record.library_nominal_sdev,
          read_profile:       read_profile(run_id)
        }
      end

      def related_samples(study_records)
        related_runs(study_records).map{|r| r.sample }.minimize
      end

      def sample_full_detail(record)
        {
          sample_id: record["_key"],
          sample_description: record.sample_description
        }
      end

      def project_full_details(record)
        run_records    = related_runs(record)
        sample_records = related_samples(record)
        {
          submission_id: record.submission_id,

          study_id: study_id,
          study_type:            record.study_type,
          study_title:           record.study_title,

          run_id:                keys(run_records),
          run: run_records.map{|record| run_full_detail(record) },

          sample_id:             keys(sample_records),
          sample: sample_records.map{|record| sample_full_detail(record) },

          pubmed_id:             record.pubmed_id,
          pmc_id:                record.pmc_id
        }
      end

      def search_api(query, options)
        if query
          records = search(query, options)
          records.map do |record|
            run_records = related_runs
            sample_records = related_samples

            {
              submission_id:         record.submission_id,
              study_id:              record["_key"],
              study_type:            record.study_type,
              study_title:           record.study_title,
              run_id:                keys(run_records),
              experiment_id:         run_records.map{|r| r.experiment_id }.minimize,
              sequencing_instrument: run_records.map{|r| r.instrument }.minimize,
              sample_id:             keys(sample_records),
              sample_organism:       sample.map{|r| r.scientific_name }.minimize,
              pubmed_id:             record.pubmed_id,
              pmc_id:                record.pmc_id
            }
          end
        end
      end

      def convert_to_study_record(id)
        case id.slice(2,1)
        when "P"
          [projetdb[id]]
        when "A"
          projectdb.select{|r| r.submission_id =~ id }
        when "X"
          projectdb.select{|r| r.run.experiment_id =~ id }
        when "S"
          projectdb.select{|r| r.run.sample.key =~ id }
        when "R"
          projectdb.select{|r| r.run.key =~ id }
        end
      end

      def convert_to_study_id(id)
        records = convert_to_study_record(id)
        if records && records.size >= 1
          records.minimize.first["_key"]
        end
      end

      def summary(study_id)
        record = projectdb[study_id]
        run_records = record.run
        sample_records = run_records.map{|r| r.sample }.minimize
        {
          study_id: study_id,
          study_title: record.study_title,
          type:        record.study_type,
          instrument:  run_records.map{|r| r.instrument }.minimize,
          species:     sample_records.map{|r| r.scientific_name }.minimize,
        }
      end

      def paper(study_id)
        paper_summary(study_id)
      end

      def paper_summary(study_id)
        pubmed_id_list = projectdb[study_id].pubmed_id
        pubmed_id_list.map do |pubmed_id|
          sum = pubmed_summary(pubmed_id)
          sum[:pmc] = pmc_summary(sum[:pmc_id])
        end
      end

      def pmc(pmc_id)
        pmc_summary(pmc_id)
      end

      def pubmed_summary(pubmed_id)
        parser = PubMedMetadataParser.new(open(eutils_xml(:pubmed, pubmed_id)))
        {
          pubmed_id:   pubmed_id,
          pmc_id:      parser.pmcid,
          journal:     parser.journal_title,
          title:       parser.article_title,
          abstract:    parser.abstract,
          affiliation: parser.affiliation,
          authors:     parser.authors.map{|a| a.values.join("\s") },
          date:        parser.date_created.values.join("/"),
        }
      end

      def pmc_summary(pmc_id)
        parser = PMCMetadataParser.new(open(eutils_xml(:pmc, pmc_id)))
        body = parser.body.compact
        {
          pmc_id:    pmc_id,
          methods:   body.select{|s| s[:sec_title] =~ /methods/i },
          results:   body.select{|s| s[:sec_title] =~ /results/i },
          reference: parser.ref_journal_list,
          cited_by:  parser.cited_by
        }
      end

      def eutils_xml(db_type, id)
        base = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml"
        base + "&db=#{db_type}&id=#{id}"
      end

      def run_table(study_id)
        record = projectdb[study_id]
        run_records = record.run
        run_records.map do |run_record|
          run_id = run_record["_key"]
          sample_records = run_record.sample
          {
            run_id:             run_id,
            experiment_id:      run_record.experiment_id,
            submission_id:      run_record.submission_id,
            sample_id:          keys(sample_records),
            study_type:         record.study_type,
            instrument:         run_record.instrument,
            lib_strategy:       run_record.library_strategy,
            lib_source:         run_record.library_source,
            lib_selection:      run_record.library_selection,
            lib_layout:         run_record.library_layout,
            lib_orientation:    run_record.library_orientation,
            lib_nominal_length: run_record.library_nominal_length,
            lib_nominal_sdev:   run_record.library_nominal_sdev,
            species:            sample_records.map{|r| r.scientific_name }.minimize,
            read_profile:       read_profile(run_id)
          }
        end
      end

      def read_profile(run_id)
        dpath = File.join(fastqc_dir, run_id.sub(/...$/,""), run_id)
        Dir.entries(dpath).select{|f| f =~ /#{run_id}/ }.map do |read|
          data_path = File.join(path, read, "fastqc_data.txt")
          parser = FastQCParser.new(data_path)
          {
            read_id:    read.sub(/_fastqc$/,""),
            total_seq:  parser.total_sequences,
            seq_length: parser.sequence_length
          }
        end
      rescue Errno::ENOENT
        nil
      end

      def fastqc_dir
        File.join(PROJ_ROOT, 'db', 'fastqc')
      end

      def sample_table(study_id)
        record = projectdb[study_id]
        run_records = record.run
        sample_records = run_records.map{|r| r.sample }.minimize
        sample_records.map do |sample_record|
          row = sample_column_values(sample_record)
          row[run_id_list] = keys(run_records)
          row
        end
      end

      def sample_column_values(record) ##
        {
          sample_id: record["_key"],
          sample_description: record.sample_description
        }
      end

      def project_report(study_id)
        {
          summary: summary(study_id),
          paper:   paper(study_id),
          run_table: run_table(study_id),
          sample_table: sample_table(study_id)
        }
      end

      def run_report(read_id)
        fpath = fastqc_fpath(read_id)
        if File.exist?(fpath)
          parse_fastqc(read_id, fpath)
        end
      end

      def fastqc_fpath(read_id)
        run_id = read_id.sub(/_(1|2)$/,"")
        prefix = run_id.sub(/...$/,"")
        File.join(fastqc_dir, prefix, run_id, read_id + "_fastqc", "fastqc_data.txt")
      end

      def parse_fastqc(read_id, fpath)
        parser = FastQCParser.new(fpath)
        {
          read_id:                   read_id,
          file_type:                 parser.file_type,
          encoding:                  parser.encoding,
          total_sequences:           parser.total_sequences,
          filtered_sequences:        parser.filtered_sequences,
          sequence_length:           parser.sequence_length,
          percent_gc:                parser.percent_gc,
          overrepresented_sequences: parser.overrepresented_sequences,
          kmer_content:              parser.kmer_content
        }
      end

      def download_link(sub_id, exp_id, run_id)
        ddbj_base = "ftp://ftp.ddbj.nig.ac.jp/ddbj_database/dra"
        ebi_base = "ftp://ftp.sra.ebi.ac.uk/vol1/fastq"
        ncbi_base = "ftp://ftp-trace.ncbi.nlm.nih.gov/sra/sra-instant/reads/ByRun/sra"
        {
          dra_fastq: File.join(ddbj_base, "fastq", sub_id.sub(/...$/,""), sub_id, exp_id),
          dra_sra:   File.join(ddbj_base, "sralite/ByExp/litesra", exp_id.slice(0..2), exp_id.sub(/...$/,""), exp_id),
          ena_fastq: File.join(ebi_base, run_id.sub(/...$/,""), run_id),
          ncbi_sra:  File.join(ncbi_base, run_id.slice(0..2), run_id.sub(/...$/,""), run_id)
        }
      end
    end
  end
end


=begin
  def export_run(study_id)

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

=end
