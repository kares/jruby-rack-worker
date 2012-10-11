require 'test/unit'
require 'test/unit/context'
require 'mocha'

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