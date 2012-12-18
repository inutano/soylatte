# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "./lib/facet_controller"


def logging(query)
  log = #{query} + "\t" + Time.now.to_s
  open(Logfile,"a"){|f| f.puts}
end

def query_filter(query_raw)
  query_raw
end

def total_count
  db = FacetController.new
  total = db.size
  #db.close
  total
end

def soy_filter(condition)
  db = FacetController.new
  
  tax = condition[:taxonid]
  stu = condition[:study_type]
  ins = condition[:instrument]

  filtered = { taxonid: db.count_taxon_id(tax),
               study_type: db.count_study_type(stu),
               instrument: db.count_instrument(ins),
               on_demand: db.count_on_demand(tax, stu, ins) }
  #db.close
  filtered
end

def soy_search(query)
  if query
    db = FacetController.new
    result = db.search_fulltext(query)
    #db.close
    result
  end
end

def get_material
  { id: "SRP000001",
    pmid: "11111111",
    text: "example project" }
end

set :haml, :format => :html5

configure do
  Configuration = YAML.load_file("./lib/config.yaml")
  Logfile = Configuration["logfile"]
end

before do
   logging(query) if params[:query]
end

get "/style.css" do
  sass :style
end

get "/" do
  haml :index
end

post "/filter" do
  db_path = Configuration["db_path"]
  FacetController.connect_db(db_path)

  @sp = params[:species]
  @st = params[:study_type]
  @pl = params[:platform]
  
  @total_number = total_count

  taxonid = @sp
  study_type = @st
  instrument = @pl
  condition = { taxonid: taxonid, study_type: study_type, instrument: instrument }
  @number_of_records = soy_filter(condition)
  
  db = FacetController.new
  db.close

  haml :filter
end

post "/search" do
  db_path = Configuration["db_path"]
  FacetController.connect_db(db_path)

  query_raw = params[:search_query]
  @query = query_filter(query_raw)
  @result = soy_search(@query)
  puts @result

  db = FacetController.new
  db.close

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
