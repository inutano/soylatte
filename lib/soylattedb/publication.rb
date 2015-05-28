# :)

require 'groonga'

class SoylatteDB
  class Publication
    class << self
      def load(db, sub_id_list)
        load_pubmed(db, sub_id_list)
        load_pmc(db, sub_id_list)
      end

      def load_pubmed(db, sub_id_list)
      end

      def load_pmc(db, sub_id_list)
      end

      def get_publication_xml
        base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&"
        pairs = { :pubmed => get_pubmed_id(@sub_id),
                  :pmc    => get_pmc_id(@sub_id)     }
        pairs.each_pair do |type, ids|
          base + "db=#{type}&id=#{ids.join(",")}"
        end
      end
    end
  end
end

=begin
    # hash for { pmid => [studyid1, studyid2, ..] } or { pmcid => [studyid1, studyid2, ...] }
    def bulk_description(hash, projects)
      num_of_parallel = 100
      while !hash.empty?
        pubid_studyids = Hash.new([])
        id_list = []
        times_loop = num_of_parallel > hash.size ? hash.size : num_of_parallel
        times_loop.times do
          item = hash.shift
          pubid = item[0]
          studyids = item[1]

          id_list << item[0]
          pubid_studyids[pubid] = studyids
        end
        DBupdate.new(id_list).bulk_retrieve.each_pair do |id, text|
          studyids = pubid_studyids[id]
          studyids.each do |studyid|
            record = projects[studyid]
            exists = record[:search_fulltext]
            record[:search_fulltext] = [exists, text].join("\s")
          end
        end
      end
    end
    bulk_description(pmid_hash, projects)
    bulk_description(pmcid_hash, projects)

=end
