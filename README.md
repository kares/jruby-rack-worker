JRuby Rack Worker
=================

Java based thread worker implementation over [jruby-rack](http://github.com/nicksieger/jruby-rack).

Natively supports [Delayed::Job](http://github.com/collectiveidea/delayed_job) and
[Navvy](http://github.com/jeffkreeftmeijer/navvy) but one can easily write his own
worker loop.


Motivation
----------

While migrating a rails application to [JRuby](http://jruby.org) I found myself
stuck with [Delayed::Job](http://github.com/collectiveidea/delayed_job). I wanted
to deploy the application without having to spawn a separate daemon process in
another *Ruby* (as *JRuby* is not daemonizable the [daemons](http://daemons.rubyforge.org)
way).

Well, why not spawn a "daemon" thread looping over the jobs from the servlet
container ... after all the java world is inherently thread-oriented !

This does have the advantage of keeping the deployment simple and saving some
precious memory (most notably with `threadsafe!` mode) that would have been
eaten by the separate process. Besides, your daemons start benefiting from
JRuby's (as well as Java's) runtime optimalizations ...

On the other hand your jobs should be simple and complete "fast" (in a rate of
seconds rather than several minutes or hours) as they will restart and live with
the lifecycle of the deployed application and/or application server.

Java purist might objects the servlet specification does not advise spawning
daemon threads in a servlet container, objection noted. Whether this style of
asynchronous processing suits your limits, needs and taste is entirely up to
You.


Setup
=====

Copy the `jruby-rack-worker.jar` into the `lib` folder or the directory being
mapped to `WEB-INF/lib` e.g. `lib/java`.

Configure the worker in `web.xml`, You'll need to add a servlet context listener
that will start threads when You application boots and a script to be executed
(should be an "endless" loop-ing script). Sample configuration :

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

**NOTE**: The `WorkerContextListener` needs to be executed (and thus configured)
after the `RailsServletContextListener`/`RackServletContextListener` as it expects
the *jruby-rack* environment to be available.

**NOTE**: If You're not using `threadsafe!` than You really **should** ...

**NOTE**: If You're still not using `threadsafe!` mode than You're polling several
(non-thread-safe) JRuby runtimes instances while serving requests, the *workers
are nor running as a part of the application* thus each worker thread will remove
and use (block) an application runtime from the instance pool (consider it while
setting the `jruby.min.runtimes`/`jruby.max.runtimes` parameters) !

Sample Rails `web.xml` usable with [Warbler](http://caldersphere.rubyforge.org/warbler)
including optional configuration parameters
[web.xml](/kares/jruby-rack-worker/blob/master/src/test/resources/warbler.web.xml).

A simpler configuration using the built-in `Delayed::Job` / `Navvy` support :

    <context-param>
      <param-name>jruby.worker</param-name>
      <param-value>delayed_job</param-value> <!-- or navvy -->
    </context-param>

    <listener>
      <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
    </listener>


Build
=====

[JRuby](http://jruby.org) 1.5+ is required to build the project.
The build is performed by [rake](http://rake.rubyforge.org) which should be part
of the JRuby installation, if You're experiencing conflicts with another Ruby and
it's rake executable use `jruby -S rake` instead of the bare `rake` command.

Build the `jruby-rack-worker.jar` using :

    rake jar

Build the gem (includes the jar) :

    rake gem

Run the tests with :

    rake test


Worker Migration
================

There are a few gotchas to keep in mind when migrating a worker such as
[Delayed::Job](http://github.com/collectiveidea/delayed_job) to JRuby, You'll
most probably need to start by looking at the current worker spawning script
(such as `script/delayed_job`) :

 * avoid native gems such as daemons (in DJ's case this means avoiding the whole
   `Delayed::Command` implementation)

 * remove command line processing - all your configuration should happen in an
   application initializer or the `web.xml`

 * make sure the worker code is thread-safe in case your application is running
   in `threadsafe!` mode (make sure no global state is changing by the worker or
   class variables are not being used to store worker state)

 * refactor your worker's exit code from a (process oriented) signal based `trap`
   to `at_exit` - which respects better the JRuby environment your workers are
   going to run in


See the [Delayed::Job](/kares/jruby-rack-worker/tree/master/src/main/ruby/delayed)
JRuby "adapted" worker code for inspiration.
