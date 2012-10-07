require File.expand_path('test_helper', File.dirname(__FILE__) + '/..')
require 'resque/jruby_worker'

module Resque
  class JRubyWorkerTest < Test::Unit::TestCase
    
    startup do
      JRuby::Rack::Worker.load_jar
    end
    
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
      assert_true new_worker.cant_fork
    end

    test "still can't fork after fork" do
      worker = new_worker
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
      def job.perform
        @performed = true
      end
      worker.expects(:reserve).returns(job)
      worker.work
      assert_true job.instance_variable_get('@performed')
    end
    
    test "to_s is made of 'hostname:pid[thread-name]:queues'" do
      worker = nil; lock = java.lang.Object.new
      thread = java.lang.Thread.new do
        begin
          worker = Resque::JRubyWorker.new('q1', 'q2')
          assert_not_nil worker.to_s
        ensure
          lock.synchronized { lock.notify }
        end
      end
      thread.name = 'worker_1'
      thread.start
      lock.synchronized { lock.wait }
      
      parts = worker.to_s.split(':')
      assert_equal 3, parts.length, parts.inspect
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
      worker.stubs(:redis).returns redis = mock('redis')
      redis.expects(:sadd).with :workers, worker
      redis.stubs(:set)
      worker.register_worker
      
      workers = Resque::JRubyWorker.system_registered_workers
      assert_include workers, worker.id
    end

    test "unregisters a worker from system" do
      worker = new_worker
      worker.send(:system_register_worker)
      
      worker.stubs(:redis).returns redis = mock('redis')
      redis.expects(:srem).with :workers, worker
      redis.stubs(:get); redis.stubs(:del)
      worker.unregister_worker
      
      workers = Resque::JRubyWorker.system_registered_workers
      assert_not_include workers, worker.id
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
      worker.verbose = true
      worker.logger = logger = mock('logger')
      logger.expects(:info).once.with { |msg| msg =~ /huu!/ }
      worker.log 'huu!'
    end

    test "uses logger.debug when logging very-verbose" do
      worker = new_worker
      worker.very_verbose = true
      worker.logger = logger = mock('logger')
      logger.expects(:debug).once.with { |msg| msg =~ /huu!/ }
      worker.log 'huu!'
    end
    
    begin
      require 'redis/client'
      Redis::Client.new.connect
      # context "REDIS" do
      
      test "worker exists after it's started" do
        worker = Resque::JRubyWorker.new('foo')
        assert_false Resque::Worker.exists?(worker.id)
        worker.startup
        assert_true Resque::Worker.exists?(worker.id), 
          "#{worker} does not exist in: #{Resque::Worker.all.inspect}"
        assert_equal worker, Resque::Worker.find(worker.to_s)
      end

      test "worker find returns correct class" do
        worker = Resque::JRubyWorker.new('bar')
        worker.startup
        found = Resque::Worker.find(worker.to_s)
        assert_equal worker.class, found.class
      end

      test "worker (still) finds a plain-old worker" do
        worker = Resque::Worker.new('huu')
        worker.startup
        assert found = Resque::Worker.find(worker.id)
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
      
      test "works (integration)" do
        worker = Resque::JRubyWorker.new('low')
        worker.startup
        
        Resque.enqueue(TestJob, 42)
        Thread.new do
          worker.work(0.25)
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
      
      # end
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
    
    def new_worker
      Resque::JRubyWorker.new('*')
    end
    
  end
end