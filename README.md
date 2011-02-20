JRuby Rack Worker
=================

Java based thread worker implementation over
[http://github.com/nicksieger/jruby-rack](jruby-rack).

Motivation
----------

While migrating a rails application to [http://jruby.org](jruby) I found myself
stuck with [http://github.com/collectiveidea/delayed_job](delayed_job). I wanted
to deploy the application without having to spawn a separate daemon process in
another *ruby* (as *jruby* is not daemonizable the
[http://daemons.rubyforge.org](daemons) way).

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
      <param-value>require 'delayed/worker'; Delayed::Worker.new.start</param-value>
    </context-param>

    <listener>
      <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
    </listener>

*NOTE*: The `WorkerContextListener` needs to be executed (and thus configured)
after the `RailsServletContextListener`/`RackServletContextListener` as it expects
the jruby-rack environment to be available !

*NOTE*: If You're not using `threadsafe!` than You really *should* !

*NOTE*: If You're still not using `threadsafe!` mode than You're polling several
(non-thread-safe) jruby runtimes instances while serving requests, the *workers
run as part of Your application* thus each worker thread will remove and use an
application runtime from Your instance pool (consider it while setting the
`jruby.min.runtimes`/`jruby.max.runtimes` parameters) !

Here's a sample Rails [/test/resources/warbler.web.xml](web.xml) usable with
[http://caldersphere.rubyforge.org/warbler/](Warbler) including optional
configuration parameters.

Build
=====

[http://jruby.org/](JRuby) 1.5+ is required to build the project.
The build is performed by [http://rake.rubyforge.org/](rake) which should be part
of Your JRuby installation, if You're experiencing conflicts with another Ruby and
it's rake executable use `jruby -S rake` instead of the bare `rake` command.

Build the `jruby-worker.jar` using :

    rake jar

Run the tests with :

    rake test
