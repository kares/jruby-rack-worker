module JRuby
  module Rack
    module Worker

      def self.log_error(e, prefix = nil)
        return unless ( logger = self.logger )

        if e.is_a?(String)
          message = "#{prefix}#{e}"
        else
          message = "#{prefix}#{e.message} (#{e.class})"
          if backtrace = e.backtrace
            message << ":\n  #{backtrace.join("\n  ")}"
          end
        end

        logger.error(message)
      end

      @@logger = nil
      def self.logger
        @@logger ||= begin
          if defined? Rails.logger # NOTE: move out
            Rails.logger
          elsif defined? JRuby::Rack.logger
            JRuby::Rack.logger
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

      def self.logger?; @@logger end

      protected

      def self.default_logger
        require 'logger'; Logger.new(STDERR)
      end

    end
  end
end