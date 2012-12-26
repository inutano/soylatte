# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "./lib/database"
require "./lib/project_report"

def logging(query)
  logfile = YAML.load_file("./lib/config.yaml")["logfile"]
  log = Time.now.to_s + "\t" + query
  open(logfile,"a"){|f| f.puts(log) }
end

def query_filter(query_raw)
  query_raw
end

set :haml, :format => :html5

before do
  query = params[:search_query]
  logging(query) if query
end

get "/style.css" do
  sass :style
end

get "/" do
  haml :index
end

post "/filter" do
  condition = { taxonid: params[:species],
                study_type: params[:study_type],
                instrument: params[:platform] }
  @total_number = Database.instance.size
  @result = Database.instance.filter(condition)
  haml :filter
end

post "/search" do
  query_raw = params[:search_query]
  @query = query_filter(query_raw)
  
  @result = Database.instance.search_fulltext(@query)
  if @result
    haml :search
  else
    haml :search_failed
  end
end

get %r{/view/((S|E|D)RP\d\{6\})$} do |id, db|
  ProjectReport.load_files("./lib/config.yaml")
  @report = ProjectReport.new(id).report
  haml :view_project
end

not_found do
  haml :not_found
end
