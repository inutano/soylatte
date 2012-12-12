# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "./lib/facet_controller"

Configuration = YAML.load_file("./lib/config.yaml")
Logfile = Configuration["logfile"]

def logging(query)
  log = #{query} + "\t" + Time.now.to_s
  open(Logfile,"a"){|f| f.puts}
end

def query_filter(query_raw)
  query_raw
end

def soy_filter(condition)
  db = FacetController.new
  
  tax = condition[:taxonid]
  stu = condition[:study_type]
  ins = condition[:instrument])

  { taxonid: db.count_taxon_id(tax),
    study_id: db.count_study_type(stu),
    instrument: db.count_instrument(ins),
    on_demand: db.count_on_demand(tax, stu, ins) }
end

def soy_search(query)
  if query
    db = FacetController.new
    db.search_fulltext(query)
  end
end

def get_material
  { id: "SRP000001",
    pmid: "11111111",
    text: "example project" }
end

set :haml, :format => :html5

before do
   logging(query) if params[:query]
end

get "/" do
  haml :index
end

post "/filter" do
  @sp = params[:species]
  @st = params[:study_type]
  @pl = params[:platform]
  
  taxonid = sp
  study_type = st
  instrument = pl
  condition = { taxonid: taxonid, study_type: study_type, instrument: instrument }
  @number_of_records = soy_filter(condition)
  haml :filter
end

post "/search" do
  query_raw = params[:query]
  query = query_filter(query_raw)
  @result = soy_search(query)
  if @result
    haml :search
  else
    haml :search_failed
  end
end

get %r{/view/((S|E|D)RP\d\{6\})$} do |id, db|
  @material = get_material(id)
  haml :view_project
end

not_found do
  haml :not_found
end
