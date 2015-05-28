# :)

require 'groonga'

class SoylatteDB
  class Publication
    class << self
      def load(db, sub_id_list)
        pubmed_id_pair = Hash.new([])
        pmc_id_pair = Hash.new([])
        sub_id_list.each do |sub_id|
          record    = Groonga["SubIDs"][sub_id]
          study_id  = record.study_id
          pubmed_id_pair[record.pubmed_id] << study_id
          pmc_id_pair[record.pmc_id]       << study_id
        end
        load_pubmed(db, pubmed_id_pair)
        load_pmc(db, pubmed_id_pair)
      end
      
      def load_publication(db, type, pub_id_pair)
        publication_id_list      = pub_id_pair.keys
        publication_id_text_pair = bulk_parse(type, publication_id_list)
        publication_id_text_pair.each_pair do |pub_id, text|
          study_id_list = pub_id_pair[pub_id]
          study_id_list.each do |study_id|
            exist = Groonga["Projects"][:search_fulltext]
            Groonga["Projects"][:search_fulltext] = [exist, text].join("\s")
          end
        end
      end
      
      def bulk_parse(type, publication_id_list)
        case type
        when :pubmed
          bulk_pubmed_parse(publication_id_list)
        when :pmc
          bulk_pmc_parse(publication_id_list)
        end
      end
      
      def bulk_pubmed_parse(pubmed_id_list)
      end

      def bulk_pmc_parse(pmc_id_list)
      end
      
      def eutils_path(type, id_list)
        base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&"
        base + "db=#{type}&id=#{id_list.join(",")}"
      end
    end
  end
end

=begin

  def bulkpubmed_parse(xml)
    pmid_text = Hash.new("")
    Nokogiri::XML(xml).css("PubmedArticle").each do |article|
      p = PubMedMetadataParser.new(article.to_xml)
      text = []
      text << p.journal_title
      text << p.article_title
      text << p.abstract
      text << p.affiliation
      text << p.authors.map{|n| n.values.compact }
      text << p.chemicals.map{|n| n[:name_of_substance] }
      text << p.mesh_terms.map{|n| n.values.compact }
      pmid_text[p.pmid] = clean_text(text.join("\s"))
    end
    pmid_text
  rescue Errno::ENETUNREACH
    sleep 180
    retry
  end

  def bulkpmc_parse(xml)
    pmcid_text = Hash.new("")
    Nokogiri::XML(xml).css("article").each do |article|
      p = PMCMetadataParser.new(article.to_xml)
      ref_journal_list = p.ref_journal_list || []
      cited_by         = p.cited_by || []
      
      text = []
      text << ref_journal_list.map{|n| n.values }
      text << cited_by.map{|n| n.values }
      text << pmc_body_text(p)
      
      # set key/pmcid, value/text
      pmcid_text["PMC" + p.pmcid] = clean_text(text.join("\s"))
    end
    pmcid_text
  rescue Errno::ENETUNREACH
    sleep 180
    retry
  end
  
  def pmc_body_text(pmc_parser)
    pmc_parser.body.compact.map do |section|
      if section.has_key?(:subsec)
        [section[:sec_title], section[:subsec].map{|subsec| subsec.values }]
      else
        section.values
      end
    end
  end

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
