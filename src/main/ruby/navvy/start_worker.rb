require 'jruby/rack/worker/logger'
begin
  require 'navvy/jruby_worker'
  Navvy::JRubyWorker.start
rescue => e
  JRuby::Rack::Worker.log_error(e) || raise
end