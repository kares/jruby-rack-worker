require 'test/unit'
require 'mocha'

module JRuby
  module Rack
    module Worker
      
      def self.load_worker_jar
        require 'java'
        runtime_jars.each { |jar| require jar }
        require worker_jar
      end

      def self.runtime_jars # ivy runtime jars
        base_dir = File.expand_path('../../..', File.dirname(__FILE__))
        Dir.glob("#{base_dir}/lib/runtime/*.jar").reject do |jar|
          jar =~ /jruby-complete/ || jar =~ /geronimo/
        end
      end

      def self.worker_jar
        base_dir = File.expand_path('../../..', File.dirname(__FILE__))
        Dir.glob("#{base_dir}/out/jruby-rack-worker_*.jar").last
      end
      
    end
  end
end