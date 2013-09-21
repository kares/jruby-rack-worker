require File.expand_path('test_helper', File.dirname(__FILE__) + '/..')
require 'resque/jruby_worker'

gem_spec = Gem.loaded_specs['resque'] if defined? Gem
puts "loaded gem 'resque' '#{gem_spec.version.to_s}'" if gem_spec

module Resque
  class JRubyWorkerTest < Test::Unit::TestCase

    def self.startup
      JRuby::Rack::Worker.load_jar
    end

    RESQUE_2x = Resque::JRubyWorker::RESQUE_2x

    test "new fails without a queue arg" do
      assert_raise(Resque::NoQueueError) do
        Resque::JRubyWorker.new
      end
    end

    test "new does not fail with a queue arg" do
      assert_nothing_raised do
        Resque::JRubyWorker.new('*')
      end
    end

    #test "worker_pids returns nothing" do
    #  assert_nil new_worker.worker_pids
    #end

    test "can't fork" do
      worker = new_worker
      omit_unless worker.respond_to?(:cant_fork)
      assert_true worker.cant_fork
    end

    test "still can't fork after fork" do
      worker = new_worker
      omit_unless worker.respond_to?(:cant_fork)
      assert_nil worker.fork
      assert_true worker.cant_fork
    end

    test "loops on work and does not change $0" do
      worker = new_worker
      worker.expects(:loop).once
      worker.stubs(:register_worker)
      worker.stubs(:prune_dead_workers)
      worker.stubs(:unregister_worker)
      worker.work

      assert_program_name_not_changed
    end

    test "performs the reserved job on work" do
      worker = new_worker
      worker.stubs(:register_worker)
      worker.stubs(:prune_dead_workers)
      worker.stubs(:working_on)
      worker.stubs(:done_working)
      worker.stubs(:unregister_worker)

      worker.stubs(:loop).yields
      payload = { 'class' => Object, 'args' => [] }
      job = Resque::Job.new('high', payload)

      worker.expects(:reserve).returns(job)
      worker.expects(:perform).with(job).once

      worker.work

      assert_program_name_not_changed
    end

    test "performs the reserved job on work (func)" do
      worker = new_worker
      worker.stubs(:register_worker)
      worker.stubs(:prune_dead_workers)
      worker.stubs(:working_on)
      worker.stubs(:done_working)
      worker.stubs(:unregister_worker)

      worker.stubs(:loop).yields
      payload = { 'class' => Object, 'args' => [] }
      job = Resque::Job.new('high', payload)
      def job.perform; @performed = true; end
      worker.expects(:reserve).returns(job)

      worker.work

      assert_true job.instance_variable_get('@performed')
    end

    test "to_s is made of 'hostname:pid[thread-name]:queues'" do
      worker = nil; lock = java.lang.Object.new
      thread = java.lang.Thread.new do
        begin
          worker = Resque::JRubyWorker.new('q1', 'q2')
          assert worker.to_s
        rescue => e
          fail_in_thread e
        ensure
          lock.synchronized { lock.notify }
        end
      end
      thread.name = 'worker_1'
      thread.start
      lock.synchronized { lock.wait }

      assert worker, "thread has not completed creating a worker yet"

      parts = worker.to_s.split(':')
      assert_equal 3, parts.length
      require 'socket'
      assert_equal Socket.gethostname, parts[0]
      assert_equal "#{Process.pid}[worker_1]", parts[1]
      assert_equal "q1,q2", parts[2]

      assert_equal worker.to_s, worker.id
    end

    test "prunes dead workers if the pid is not a live process" do
      worker1 = new_worker
      worker1.stubs(:pid).returns('99999')
      Resque::JRubyWorker.stubs(:all).returns [ worker1 ]

      worker1.expects(:unregister_worker).once
      new_worker.prune_dead_workers
    end

    test "pruning dead workers work for non-jruby workers as well (if pid not a live process)" do
      worker1 = Resque::Worker.new('some')
      worker1.stubs(:pid).returns('99999')
      Resque::JRubyWorker.stubs(:all).returns [ worker1 ]

      worker1.expects(:unregister_worker).once
      new_worker.prune_dead_workers
    end

    test "does not prune a worker if not the same hostname" do
      worker1 = new_worker
      worker1.stubs(:hostname).returns('SomeHostName')
      Resque::JRubyWorker.stubs(:all).returns [ worker1 ]

      worker1.expects(:unregister_worker).never
      new_worker.prune_dead_workers
    end

    test "prunes dead workers if thread is dead" do
      worker1 = new_worker
      worker1.stubs(:thread_id).returns('worker#666')
      Resque::JRubyWorker.stubs(:all).returns [ worker1 ]

      worker1.expects(:unregister_worker).once
      new_worker.prune_dead_workers
    end

    test "does not prune dead workers if thread is live" do
      thread = java.lang.Thread.new { sleep(0.5) }
      thread.name = 'workerx#42'
      thread.start
      worker1 = new_worker
      worker1.stubs(:thread_id).returns('workerx#42')
      Resque::JRubyWorker.stubs(:all).returns [ worker1 ]

      worker1.expects(:unregister_worker).never
      new_worker.prune_dead_workers
    end

    test "registers a worker with the system" do
      worker = new_worker
      if RESQUE_2x
        worker.worker_registry.stubs(:redis).returns redis = mock('redis')
      else
        worker.stubs(:redis).returns redis = mock('redis')
      end
      redis.stubs(:pipelined).yields
      redis.expects(:sadd).with :workers, worker
      redis.stubs(:set)

      if RESQUE_2x
        worker.worker_registry.register
      else
        worker.register_worker
      end

      workers = Resque::JRubyWorker.system_registered_workers
      assert_include workers, worker.id
    end

    test "unregisters a worker from system" do
      worker = new_worker
      worker.send(:system_register_worker)
      if RESQUE_2x
        worker.worker_registry.stubs(:redis).returns redis = mock('redis')
      else
        worker.stubs(:redis).returns redis = mock('redis')
      end
      redis.stubs(:pipelined).yields

      redis.expects(:srem).with :workers, worker
      redis.stubs(:get); redis.stubs(:del)

      if RESQUE_2x
        worker.worker_registry.unregister
      else
        worker.unregister_worker
      end

      workers = Resque::JRubyWorker.system_registered_workers
      assert_not_include workers, worker.id
    end

    test "unregisters worker raises when exception given" do
      worker = new_worker
      worker.stubs(:redis).returns redis = mock('redis')
      redis.stubs(:pipelined).yields
      redis.stubs(:srem).with :workers, worker
      redis.stubs(:get); redis.stubs(:del)

      exception = RuntimeError.new('unregister test')
      unregister_worker_arg =
        Resque::Worker.instance_method(:unregister_worker).arity != 0 rescue nil
      if unregister_worker_arg
        assert_nothing_raised(RuntimeError) do
          worker.unregister_worker(exception)
        end
      elsif ! unregister_worker_arg.nil?
        assert_raise(RuntimeError) do
          worker.unregister_worker(exception)
        end
      else # Resque 2.x
        assert_nothing_raised(RuntimeError) do
          worker.worker_registry.unregister(exception)
        end
      end
    end

    test "split worker id" do
      assert_equal [ 'host', '42', nil, '*' ],
        Resque::JRubyWorker.split_id("host:42:*")
      assert_equal [ 'host', '42', '*' ],
        Resque::JRubyWorker.split_id("host:42:*", nil)

      assert_equal [ 'host', '42', 'thread:main', 'foo,bar' ],
        Resque::JRubyWorker.split_id("host:42[thread:main]:foo,bar")
      assert_equal [ 'host', '42', 'foo,bar' ],
        Resque::JRubyWorker.split_id("host:42[thread:main]:foo,bar", nil)
    end

    test "uses logger.info when logging verbose" do
      worker = new_worker
      with_logger_severity_deprecation(:off) do
        worker.verbose = true if worker.respond_to?(:verbose)
        worker.logger.expects(:info).once.with { |msg| msg =~ /huu!/ }
        worker.log 'huu!'
      end
    end

    test "uses logger.debug when logging very-verbose" do
      worker = new_worker
      with_logger_severity_deprecation(:off) do
        worker.very_verbose = true if worker.respond_to?(:very_verbose)
        worker.logger.expects(:debug).once.with { |msg| msg =~ /huu!/ }
        worker.log! 'huu!'
      end
    end

    test "returns a logger instance" do
      worker = new_worker
      assert_kind_of Logger, worker.logger
    end

    test "registers 'signal handlers' on startup" do
      worker = new_worker
      worker.stubs(:prune_dead_workers)
      worker.expects(:register_signal_handlers)
      worker.startup
    end

    test "sets up an at_exit hook on register_signal_handlers" do
      worker = new_worker
      worker.expects(:at_exit).once
      worker.register_signal_handlers
    end

    test "shuts down worker from at_exist registered hook" do
      worker = new_worker
      def worker.at_exit(&block)
        @_at_exit_block = block
      end
      def worker.call_at_exit
        @_at_exit_block.call
      end
      worker.register_signal_handlers
      assert ! worker.shutdown?
      worker.call_at_exit
      assert_true worker.shutdown?
    end

    test "starts a worker" do
      ENV['INTERVAL'] = '3.5'
      ENV['QUEUE'] = 'notifications'
      begin
        expected_args = [ ENV['QUEUE'] ]
        expected_args << {
          :interval => 3.5,
          :daemon => false,
          :fork_per_job => false,
          :run_at_exit_hooks => true
        } if RESQUE_2x

        worker = Resque::JRubyWorker.new(expected_args)

        Resque::JRubyWorker.expects(:new).with(*expected_args).returns worker

        if RESQUE_2x
          worker.expects(:work)
        else
          worker.expects(:work).with('3.5')
        end

        load 'resque/start_worker.rb'
      ensure
        ENV['INTERVAL'] = nil; ENV['QUEUE'] = nil
      end
    end

    begin
      if Resque.respond_to?(:redis=)
        require 'redis/client'
        redis = Redis::Client.new
        Resque.redis = redis.id
      else # 1.x
        require 'redis/client'
        redis = Redis::Client.new
        redis.connect
      end

      context "with redis" do

        test "worker exists after it's started" do
          worker = Resque::JRubyWorker.new('foo')
          assert_false worker_exists?(worker.id)
          worker.startup
          assert_true worker_exists?(worker.id),
            "#{worker} does not exist in: #{worker_all.inspect}"
          assert_equal worker, worker_find(worker.to_s)
        end

        test "worker find returns correct class" do
          worker = Resque::JRubyWorker.new('bar')
          worker.startup
          found = worker_find(worker.to_s)
          assert_equal worker.class, found.class
        end

        test "worker (still) finds a plain-old worker" do
          worker = Resque::Worker.new('huu')
          worker.stubs(:register_signal_handlers)
          worker.send(:startup) # protected since 2.0
          assert found = worker_find(worker.id)
          assert_equal 'Resque::Worker', found.class.name
        end

        class TestJob

          @@performed = nil

          def self.perform(param = true)
            puts "#{self}#perform(#{param.inspect})"
            raise "already performed" if @@performed
            @@performed = param
          end

          @queue = :low

        end

        test "(integration) works" do
          worker = Resque::JRubyWorker.new('low')
          with_logger_severity_deprecation(:off) do
            worker.verbose = true if worker.respond_to?(:verbose)
          end
          worker.startup

          Resque.enqueue(TestJob, 42)
          Thread.new do
            begin
              if RESQUE_2x
                worker.options.to_hash[:interval] = 0.25
                worker.work
              else
                worker.work(0.25)
              end
            rescue => e
              fail_in_thread e
            end
          end

          sleep(0.30)

          assert_match /Paused|Waiting for low/, worker.procline
          assert_equal 42, TestJob.send(:class_variable_get, :'@@performed')

          workers = Resque::JRubyWorker.system_registered_workers
          assert_include workers, worker.id
          worker.shutdown
          sleep(0.25)
          workers = Resque::JRubyWorker.system_registered_workers
          assert_not_include workers, worker.id
        end

        if defined? Resque::WorkerRegistry
          WorkerAccess = Resque::WorkerRegistry
        else
          WorkerAccess = Resque::Worker
        end

        def worker_all
          WorkerAccess.all
        end

        def worker_find(id)
          WorkerAccess.find(id)
        end

        def worker_exists?(id)
          WorkerAccess.exists?(id)
        end

      end
    rescue ( defined?(Redis::CannotConnectError) ? Redis::CannotConnectError : Errno::ECONNREFUSED ) => e
      warn "[WARNING] skipping tests that depend on redis due #{e.inspect}"
    end

    # end # REDIS

    protected

    ORIGINAL_0 = $0.dup

    def assert_program_name_not_changed
      assert_equal ORIGINAL_0, $0, "$0 changed to: #{$0}"
    end

    private

    def fail_in_thread(e)
      puts "thread failed: #{e}"
      e.backtrace.each { |b| puts b }
      raise e
    end

    def with_logger_severity_deprecation(off = true)
      severity_deprecation = $warned_logger_severity_deprecation
      $warned_logger_severity_deprecation = off
      yield
    ensure
      $warned_logger_severity_deprecation = severity_deprecation
    end

    def new_worker
      Resque::JRubyWorker.new('*')
    end

  end
end