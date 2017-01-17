begin
  require 'bundler'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end
Bundler.setup # require(:default, :test)

gem 'test-unit' # uninitialized constant Test::Unit::TestResult::TestResultFailureSupport
require 'test/unit'
require 'test/unit/context'
begin; require 'mocha/setup'; rescue LoadError; require 'mocha'; end

require 'jruby/rack/worker'

module JRuby
  module Rack
    module Worker
      
      @@load_jar = nil
      
      # NOTE: we're not packed in a .gem thus override .jar loading :
      def self.load_jar
        unless @@load_jar
          @@load_jar = true
          require 'java'
          runtime_jars.each { |jar| load jar }
          require Dir.glob("#{base_dir}/out/jruby-rack-worker_*.jar").last
        end
      end

      private
      
      def self.runtime_jars # ivy runtime jars
        Dir.glob("#{base_dir}/lib/runtime/*.jar").reject do |jar|
          jar =~ /jruby-complete/ || jar =~ /geronimo/
        end
      end
      
      def self.base_dir
        File.expand_path('../../..', File.dirname(__FILE__))
      end

    end
  end
end