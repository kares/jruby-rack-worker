require 'jruby/rack/worker/version'

module JRuby
  module Rack
    module Worker
      unless const_defined?(:JAR_PATH)
        JAR_PATH = File.expand_path("../../jruby-rack-worker_#{VERSION}.jar", File.dirname(__FILE__))
      end
      def self.load_jar(method = :load)
        send(method, JAR_PATH) # load JAR_PATH
      end
    end
  end
end