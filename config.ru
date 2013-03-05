require "bundler"

Bundler.require

require File.dirname(__FILE__) + "/app"

set :haml, :format => :html5, :escape_html => true

run SoyLatte
