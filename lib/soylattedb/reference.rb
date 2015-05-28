# :)

require 'groonga'

class SoylatteDB
  class Reference
    class << self
      def load(db)
        establish_connection(db)
        load_studyids
        load_experiments
        load_taxons
      end

      def establish_connection(db)
        Groonga::Database.open(db)
      end

      def load_studyids
        publication_ref_pair = sra_publications_pair
        study_ids_pair.each_pair do |study_id, id_hash|
          run_id_list = id_hash[:run_id]
          sub_id_list = id_hash[:sub_id]

          pubmed_id_list = []
          pmc_id_list    = []
          sub_id_list.each do |sub_id|
            pubmed_id_list << publication_ref_pair[sub_id][:pubmed_id]
            pmc_id_list    << publication_ref_pair[sub_id][:pmc_id]
          end

          Groonga["StudyIDs"].add(
            study_id,
            run_id:    run_id_list,
            pubmed_id: pubmed_id_list,
            pmc_id:    pmc_id_list
          )
        end
      end

      def study_ids_pair
        pairs = Hash.new(Hash.new([]))
        accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
        cmd = "awk -F '\t' '$1 ~ /^.RR/ { OFS=\"\t\" ; print $13, $1, $2 }' #{accessions}" # study_id, run_id, sub_id
        `#{cmd}`.split("\n").each do |ln|
          line = ln.split("\t")
          study_id = line[0]
          run_id   = line[1]
          sub_id   = line[2]

          pairs[study_id][:run_id] << run_id
          pairs[study_id][:sub_id] << sub_id
        end
        pairs
      end

      def sra_publications_pair
        publication_pair = pubmed_pmc_id_pair
        pairs = Hash.new(Hash.new([]))
        publication_json = File.join(PROJ_ROOT, "data", "publication.json")
        json = open(publication_json){|f| JSON.load(f) }
        json["ResultSet"]["Result"].each do |node|
          sub_id = node["sra_id"]
          pubmed_id = node["pmid"]
          pairs[sub_id][:pubmed_id] << pubmed_id
          pairs[sub_id][:pmc_id] << publication_pair[pubmed_id]
        end
        pairs
      end

      def pubmed_pmc_id_pair
        pairs = Hash.new("")
        pmc_ids = File.join(PROJ_ROOT, "data", "PMC-ids.csv")
        open(pmc_ids) do file
          while l = file.gets
            cols = l.split(",")
            pairs[cols[9]] = cols[8] # pubmed_id: pmc_id
          end
        end
        pairs
      end

      def load_experiments
        exp_run_id_pair.each_pair do |exp_id, run_id_list|
          Groonga["Experiments"].add(
            exp_id,
            run_id: run_id_list
          )
        end
      end

      def exp_run_id_pair
        pairs = Hash.new([])
        accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
        cmd = "awk -F '\t' '$1 ~ /^.RR/ { OFS=\"\t\" ; print $11, $1 }' #{accessions}" # exp_id, run_id
        `#{cmd}`.split("\n").each do |ln|
          line = ln.split("\t")
          exp_id = line[0]
          run_id = line[1]
          pairs[exp_id] << run_id
        end
        pairs
      end

      def load_taxons
        taxon_table = File.join(PROJ_ROOT, "data", "taxon_table.csv")
        open(taxon_table) do |file|
          while lt = file.gets
            l = lt.split(",")
            taxon_id        = l[0]
            scientific_name = l[1]
            Groonga["Taxons"].add(
              taxon_id,
              scientific_name: scientific_name
            )
          end
        end
      end
    end
  end
end
