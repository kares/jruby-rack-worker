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
the jruby-rack environment to be available !

**NOTE**: If You're not using `threadsafe!` than You really **should** !

**NOTE**: If You're still not using `threadsafe!` mode than You're polling several
(non-thread-safe) jruby runtimes instances while serving requests, the *workers
run as part of Your application* thus each worker thread will remove and use an
application runtime from Your instance pool (consider it while setting the
`jruby.min.runtimes`/`jruby.max.runtimes` parameters) !

Here's a sample Rails `web.xml` usable with
[http://caldersphere.rubyforge.org/warbler/](Warbler) including optional
configuration parameters :

    <!DOCTYPE web-app PUBLIC "-//Sun Microsystems, Inc.//DTD Web Application 2.3//EN"
                             "http://java.sun.com/dtd/web-app_2_3.dtd">
    <!--
    NOTE: some servers e.g. the awesome http://github.com/calavera/trinidad don't
          play well with the XML doctype (or namespace) declaration e.g. :

    in that case just remove the above web-app DTD or make sure there's no schema
    declared within Your web-app root XML element !
    -->
    <web-app>

        <context-param>
            <param-name>rails.env</param-name>
            <param-value>production</param-value>
        </context-param>

        <context-param>
            <param-name>public.root</param-name>
            <param-value>/</param-value>
        </context-param>

        <context-param>
            <param-name>jruby.min.runtimes</param-name>
            <param-value>1</param-value>
        </context-param>
        <context-param>
            <param-name>jruby.max.runtimes</param-name>
            <param-value>1</param-value>
        </context-param>

        <filter>
            <filter-name>RackFilter</filter-name>
            <filter-class>org.jruby.rack.RackFilter</filter-class>
        </filter>
        <filter-mapping>
            <filter-name>RackFilter</filter-name>
            <url-pattern>/*</url-pattern>
        </filter-mapping>

        <listener>
            <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>
        </listener>

        <!-- worker(s) will execute this script : -->
        <context-param>
            <param-name>jruby.worker.script</param-name>
            <param-value>require 'my_worker/worker' || MyWorker::Worker.new.start</param-value>
        </context-param>
        <!-- if You script is located in a rb file use : -->
        <!--
        <context-param>
            <param-name>jruby.worker.script.path</param-name>
            <param-value>my_worker/loop_worker.rb</param-value>
        </context-param>-->
        <!-- if one worker thread is not enough, increase the value : -->
        <context-param>
            <param-name>jruby.worker.thread.count</param-name>
            <param-value>1</param-value>
        </context-param>
        <!-- You might also change the worker thread priority (use with caution) : -->
        <!-- accepted values are MIN, MAX, NORM and integer values <1..10> -->
        <context-param>
            <param-name>jruby.worker.thread.priority</param-name>
            <param-value>NORM</param-value>
        </context-param>

        <!-- make sure it's declared after the "default" jruby-rack listener : -->
        <listener>
            <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
        </listener>

    </web-app>

Build
=====

[http://jruby.org/](JRuby) 1.5+ is required to build the project.
The build is performed by [http://rake.rubyforge.org/](rake) which should be part
of Your JRuby installation, if You're experiencing conflicts with another Ruby and
it's rake executable use `jruby -S rake` instead of the bare `rake` command.

Build the `jruby-rack-worker.jar` using :

    rake jar

Run the tests with :

    rake test
