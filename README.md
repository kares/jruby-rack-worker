JRuby Rack Worker
=================

Java based thread worker implementation over [jruby-rack](http://github.com/nicksieger/jruby-rack).

Motivation
----------

While migrating a rails application to [JRuby](http://jruby.org) I found myself
stuck with [Delayed::Job](http://github.com/collectiveidea/delayed_job). I wanted
to deploy the application without having to spawn a separate daemon process in
another *ruby* (as *jruby* is not daemonizable the [daemons](http://daemons.rubyforge.org) way).

Well, why not spawn a "daemon" thread looping over the jobs from the servlet
container ... after all the java world is inherently thread-oriented !

This does have the advantage of keeping the deployment simple and saving some
precious memory (assuming `threadsafe!` mode of course) that would have been
eaten by the separate process. Besides Your daemons start benefiting from
JRuby's (as well as Java's) runtime optimalizations !

On the other hand Your jobs should be simple and complete "fast" (in a rate of
seconds rather than several minutes or hours) as they will restart and live with
the lifecycle of the deployed application / application server.

Java purist might objects the servlet specification does not advise spawning
daemon threads in a servlet container, objection noted. Whether this style of
asynchronous processing suits Your limits, needs and taste is entirely up to U !


Setup
=====

Copy the `jruby-rack-worker.jar` into the `lib` folder or the directory being
mapped to `WEB-INF/lib` e.g. `lib/java`.

Configure the worker in Your `web.xml`, You'll need to add a servlet context
listener that will start threads when You application boots and a script to be
executed (should be an "endless" loop-ing script). Sample configuration :

    <context-param>
      <param-name>jruby.worker.script</param-name>
      <param-value>
        require 'delayed/jruby_worker'
        Delayed::JRubyWorker.new.start
      </param-value>
    </context-param>

    <listener>
      <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
    </listener>

<strong>
Script loading from WEB-INF/lib/*.jar files is not working thus make sure
(in case of the above example) that You copy all Your .rb files to the load path
(e.g. in case of the above example copy `src/main/ruby/delayed/jruby_worker.rb`
to `RAILS_ROOT/lib/delayed/jruby_worker.rb` ) ...
</strong>

**NOTE**: The `WorkerContextListener` needs to be executed (and thus configured)
after the `RailsServletContextListener`/`RackServletContextListener` as it expects
the jruby-rack environment to be available.

**NOTE**: If You're not using `threadsafe!` than You really **should** ...

**NOTE**: If You're still not using `threadsafe!` mode than You're polling several
(non-thread-safe) jruby runtimes instances while serving requests, the *workers
run as part of Your application* thus each worker thread will remove and use an
application runtime from Your instance pool (consider it while setting the
`jruby.min.runtimes`/`jruby.max.runtimes` parameters) !

Sample Rails `web.xml` usable with [Warbler](http://caldersphere.rubyforge.org/warbler)
including optional configuration parameters
[web.xml](/kares/jruby-rack-worker/blob/master/src/test/resources/warbler.web.xml).


Build
=====

[JRuby](http://jruby.org) 1.5+ is required to build the project.
The build is performed by [rake](http://rake.rubyforge.org) which should be part
of Your JRuby installation, if You're experiencing conflicts with another Ruby and
it's rake executable use `jruby -S rake` instead of the bare `rake` command.

Build the `jruby-rack-worker.jar` using :

    rake jar

Run the tests with :

    rake test


Worker Migration
================

There are a few gotchas to keep in mind when migrating a worker such as
[Delayed::Job](http://github.com/collectiveidea/delayed_job) to JRuby, You'll most
probably need to start by looking at Your worker spawning script (such as `script/delayed_job`) :

 * avoid native gems such as daemons (in DJ's case this means avoiding the whole
   `Delayed::Command` implementation)

 * remove command line processing - all Your configuration should happen in an
   initializer or the `web.xml`

 * make sure the worker code is thread-safe in case Your application is running in 
   `threadsafe!` mode (make sure no global state is changing by the worker or 
   class variables are not being used to store worker state)

 * refactor Your worker's exit code from a (process oriented) signal based `trap`
   to `at_exit` - respects better the JRuby servlet environment Your workers be
   running in

See the [Delayed::Job](/kares/jruby-rack-worker/tree/master/src/main/ruby/delayed)
JRuby "migrated" worker code for inspiration.