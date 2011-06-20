# -*- coding: utf-8 -*-

require "open-uri"
require "json"
require "nokogiri"
require "pp"
	
def fix_json(taxon_id, study_type)
	sras_url = "http://sra.dbcls.jp/cgi-bin/publication2.php?"
	url_json = "#{sras_url}type=#{study_type}&taxon_id=#{taxon_id}"
	
	sotogawa = open(url_json) { |n| JSON.load(n) }
	nakamidono = sotogawa["ResultSet"]["Result"]
	
	pubmed_metadata = []
	nakamidono.each do |nakami|
		irumono = []
		nakami.each do |naka|
			if !["vol", "issue", "page", "sra_title"].include?(naka[0])
				irumono.push(naka[1])
			end
		end
		
		pmid = irumono[0]
		url_pubmed = "http://www.ncbi.nlm.nih.gov/pubmed/#{pmid}"
		pp url_pubmed
		pubmed_html = Nokogiri::HTML(open(url_pubmed))
		pm_abstract = (pubmed_html/"div.abstr"/"p").inner_text
		pm_author = (pubmed_html/"div.auths").inner_text
		irumono.push(pm_abstract, pm_author)
		
		pubmed_metadata.push(irumono)
	end
	
	return pubmed_metadata
end

def refresh_json # refresh json data from sra.dbcls.jp after fix data with fix_json
	organism = { "Hsapiens" => "9606", "Mmusculus" => "10090", "Athaliana" => "3702", "Allspecies" => "" }
	study_type = ["Transcriptome+Analysis"]
	
	organism.each do |name, id|
		study_type.each do |type|
			pubmed_metadata = fix_json(id, type) # method defined above
			
			type_unplus = type.gsub("+","")
			open("./SRAs_json_test/#{type_unplus}_#{name}.json","w") { |f| JSON.dump(pubmed_metadata, f) }
		end
	end
end

=begin
class BuildDB
	def initialize(sub_id)
		@sub_id = sub_id
	end
	
	
	
	
=end


if __FILE__ == $0
	# build json database on local server 
	refresh_json
end
