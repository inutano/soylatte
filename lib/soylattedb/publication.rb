# :)

require 'groonga'

class SoylatteDB
  class Publication
    class << self
      def load
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
