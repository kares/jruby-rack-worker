module JRuby
  module Rack
    module Worker
      
      def self.log_error(e, logger = nil)
        return unless ( logger ||= self.logger )
        
        message = "\n#{e.class} (#{e.message}):\n"
        message << '  ' << e.backtrace.join("\n  ")
        logger.error("#{message}\n\n")
      end
      
      @@logger = nil
      def self.logger
        @@logger ||= begin
          if defined?(Rails.logger)
            Rails.logger
          else
            default_logger
          end
        end
      end
      
      def self.logger=(logger)
        if @@logger == false
          require 'logger'
          @@logger = Logger.new(nil)
        else
          @@logger = logger
        end
      end
      
      def self.logger?; !!@@logger; end
      
      protected
      
      def self.default_logger
        require 'logger'; Logger.new(STDERR)
      end
      
    end
  end
end