require "bundler"
require "rack/protection"

Bundler.require
#use Rack::Protection, :except => :session_hijacking
#use Rack::Protection::FormToken
#use Rack::Protection::EscapedParams

require File.dirname(__FILE__) + "/app"
run SoyLatte
