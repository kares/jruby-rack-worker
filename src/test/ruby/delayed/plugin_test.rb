require File.expand_path('test_helper', File.dirname(__FILE__) + '/..')
require 'delayed/jruby_worker'

module Delayed
  class PluginTest < Test::Unit::TestCase

    def self.startup
      JRuby::Rack::Worker.load_jar
    end

    def self.load_plugin!
      load_plugin_like!
      require 'delayed_cron_job' # order is important - backend needs to be loaded
      # gem: spec.add_dependency "delayed_job", ">= 4.1"
    end

    def self.load_plugin_like!
      require 'active_record'
      require 'active_record/connection_adapters/jdbcsqlite3_adapter'

      require 'delayed_job_active_record' # DJ 3.0+
    end

    setup do
      require 'logger'; require 'stringio'
      Delayed::Worker.logger = Logger.new(StringIO.new)
    end

    test "only one lifecycle instance is created" do
      self.class.load_plugin_like!

      lifecycle = Delayed::Lifecycle.new
      Delayed::Lifecycle.expects(:new).returns(lifecycle).once
      begin
        reset_worker
        threads = start_threads(3) do
          l1 = Delayed::JRubyWorker.lifecycle
          l2 = Delayed::Worker.lifecycle
          assert_same l2, l1
        end
        threads.each(&:join)
      ensure
        Delayed::Worker.reset # @lifecycle = nil
      end
    end if Worker.is_a?(SyncLifecycle)


    test "setup lifecycle does guard for lifecycle creation" do
      self.class.load_plugin_like!

      lifecycle = Delayed::Lifecycle.new
      Delayed::Lifecycle.expects(:new).returns(lifecycle).once
      begin
        reset_worker
        threads = start_threads(5) do
          Delayed::JRubyWorker.new
          sleep 0.1
          Delayed::Worker.new
        end
        threads.each(&:join)
      ensure
        Delayed::Worker.reset # @lifecycle = nil
      end
    end if Worker.is_a?(SyncLifecycle)

    context "with backend" do

      @@plugin = nil

      def self.startup
        require 'active_record'
        require 'active_record/connection_adapters/jdbcsqlite3_adapter'
        load 'delayed/active_record_schema_cron.rb'
        Delayed::Job.reset_column_information

        @@plugin = begin; load_plugin!; rescue Exception => ex; ex end
      end

      setup do
        Delayed::Worker.logger = Logger.new(STDOUT)
        Delayed::Worker.logger.level = Logger::DEBUG
        ActiveRecord::Base.logger = Delayed::Worker.logger if $VERBOSE
      end

      class CronJob

        def initialize(param)
          @param = param
        end

        @@performed = nil

        def perform
          puts "#{self}#perform param = #{@param}"
          raise "already performed" if @@performed
          @@performed = @param
        end

      end

      test "works (integration)" do
        omit "#{@@plugin.inspect}" if @@plugin.is_a?(Exception) # 'plugin not supported on DJ < 4.1'

        worker = Delayed::JRubyWorker.new({ :sleep_delay => 0.10 })
        start = Time.now
        Delayed::Job.enqueue job = CronJob.new(:boo), cron: '0-59/1 * * * *'
        Delayed::Job.where('cron IS NOT NULL').first.update_column(:run_at, Time.now)
        Thread.new { worker.start }
        sleep(0.20)
        assert ! worker.stop?

        assert_equal :boo, CronJob.send(:class_variable_get, :'@@performed')

        sleep(0.20)
        # it's re-scheduled for next run :
        assert job = Delayed::Job.where('cron IS NOT NULL').first
        puts job.inspect if $VERBOSE
        min = start.min; min_next = min + 1; min_next = 0 if min_next == 60
        assert [min, min_next].include?(job.run_at.min)

        worker.stop
        sleep(0.15)
        assert worker.stop?
      end

    end

    private

    def start_threads(count)
      raise 'no block' unless block_given?
      threads = []
      count.times do
        threads << Thread.start do
          begin
            yield
          rescue Exception => ex
            puts ex.inspect + "\n  #{ex.backtrace.join("\n  ")}"
          end
        end
      end
      threads
    end

    def reset_worker
      # Worker.reset only does `@lifecycle = nil` on DJ 4.1
      Delayed::Worker.instance_variable_set :@lifecycle, nil
      Delayed::Worker.reset
    end

  end
end
