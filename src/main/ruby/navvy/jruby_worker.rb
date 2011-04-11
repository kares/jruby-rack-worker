unless defined?(Navvy::Job)
  raise "Navvy not configured - require 'navvy' " +
        "and the desired backend in a initializer"
end

module Navvy
  class JRubyWorker < Worker

    # a thread-safe Navvy::Worker.start
    def self.start
      Navvy.logger.info '*** Starting ***'

      at_exit { exit! }

      loop do
        fetch_and_run_jobs

        break if @exit
        
        sleep sleep_time
      end
    end

    def self.exit!
      return if @exit
      Navvy.logger.info '*** Exiting ***'
      @exit = true
      Navvy.logger.info '*** Cleaning up ***'
      Navvy::Job.cleanup
    end

  end
end