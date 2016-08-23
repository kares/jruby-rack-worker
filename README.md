# JRuby-Rack-Worker

Thread based workers on top of [JRuby-Rack](http://github.com/jruby/jruby-rack).

With out of the box thread-safe [JRuby](http://jruby.org) "adapters" for:

* [Resque](http://github.com/defunkt/resque) (>= 1.21.0, ~> 2.0.0 [master])
* [Delayed::Job](http://github.com/collectiveidea/delayed_job) (~> 2.1, >= 3.0)
* [Navvy](http://github.com/jeffkreeftmeijer/navvy) (not-maintained)

... but one can easily write/adapt his own worker loop.

[![Build Status][0]](http://travis-ci.org/kares/jruby-rack-worker)

## Motivation

Ruby attempts to stay pretty close to UNIX and most popular workers have been
modeled the "spawn a background process" way. [JRuby](http://jruby.org) brings
Java to the table, where "Young Java Knights" are taught to use threads
whenever in a need to compute something in parallel with serving requests.

There's no right or wrong way of doing this. If you do expect chaos like Resque
proclaims - have long running jobs that consume a lot of memory they have trouble
releasing (e.g. due C extensions) run a separate process for sure.
But otherwise (after all C exts usually have a native Java alternative on JRuby)
having predictable thread-safely written workers, one should be fine with
running them concurrently as part of the application in a (daemon) thread.

This does have the advantage of keeping the deployment simple and saving some
precious memory (most notably with `threadsafe!` mode) that would have been
eaten by the separate process. Besides, your application might warm up faster
and start benefiting from JRuby's runtime optimalizations slightly sooner ...

On the other hand your jobs should be fairly simple and complete "fast" (in a
rate of seconds rather than several minutes or hours) as they will live and
restart with the lifecycle of the deployed application and application server.


## Setup

Copy the *jruby-rack-worker.jar* into the *lib* folder or the directory being
mapped to *WEB-INF/lib* (e.g. *lib/java*).

Configure your worker in **web.xml**, you will need to add a context listener
that will start (daemon) threads when your application boots and a script to be
executed (should be an "endless" loop-ing script). Sample configuration :

```xml
  <context-param>
    <param-name>jruby.worker.script</param-name>
    <param-value>
      <!-- any script with an end-less loop : ->
      require 'delayed/jruby_worker'
      Delayed::JRubyWorker.new.start
    </param-value>
  </context-param>

  <listener>
    <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
  </listener>
```

The `WorkerContextListener` needs to be executed (and thus configured) after the
`RailsServletContextListener`/`RackServletContextListener` as it expects the
JRuby-Rack environment to be booter and available.

For built-in worker support (if you're happy with the defaults) simply specify
the **jruby.worker** context parameter (optionally with custom params supported
by the worker) e.g. :

```xml
  <context-param>
    <param-name>jruby.worker</param-name>
    <param-value>resque</param-value>
  </context-param>
  <context-param>
    <param-name>QUEUES</param-name>
    <param-value>mails,posts</param-value>
  </context-param>
  <context-param>
    <param-name>INTERVAL</param-name>
    <param-value>2.5</param-value>
  </context-param>

  <listener>
    <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
  </listener>
```

Sample deployment descriptor including optional parameters:
[web.xml](src/test/resources/sample.web.xml).

### Threads

Number of worker threads as well as their priorities can be configured (by
default a single worker thread is started with the default NORM priority) :

- *jruby.worker.thread.count* please be sure you do not start too many threads,
  consider tuning your worker settings if possible first e.g. for DJ/Resque the
  sleep interval if you feel like the worker is not performing enough work.
- *jruby.worker.thread.priority* maps to standard (Java) thread priority which
  is a value <MIN, MAX> where MIN == 1 and MAX == 10 (the NORM priority is 5),
  this is useful e.g. if you're load gets high (lot of request serving threads)
  and you do care about requests more than about executing worker code you might
  consider decreasing the priority (by 1).

One can also skip worker startup (no workers will boot despite the configuration)
using a parameter e.g. as a Java system property: *-Djruby.worker.skip=true*.

### Warbler

If you're using [Warbler](http://github.com/jruby/warbler) to assemble your
application you might simply declare a gem dependency with Bundler as your
gems will be scanned for .jars among all gem files and packaged correctly :

    gem 'jruby-rack-worker', :platform => :jruby, :require => nil

Otherwise copy the jar into your *warble.rb* configured `config.java_libs`.

Warbler checks for a *config/web.xml.erb* (or simply a *config/web.xml*) thus
configure the worker there, e.g. :

```
<!DOCTYPE web-app PUBLIC
  "-//Sun Microsystems, Inc.//DTD Web Application 2.3//EN"
  "http://java.sun.com/dtd/web-app_2_3.dtd">
<web-app>
<% webxml.context_params.each do |k,v| %>
  <context-param>
    <param-name><%= k %></param-name>
    <param-value><%= v %></param-value>
  </context-param>
<% end %>

  <filter>
    <filter-name>RackFilter</filter-name>
    <filter-class>org.jruby.rack.RackFilter</filter-class>
  </filter>
  <filter-mapping>
    <filter-name>RackFilter</filter-name>
    <url-pattern>/*</url-pattern>
  </filter-mapping>

  <listener>
    <listener-class><%= webxml.servlet_context_listener %></listener-class>
  </listener>

<% if webxml.jndi then [webxml.jndi].flatten.each do |jndi| %>
  <resource-ref>
    <res-ref-name><%= jndi %></res-ref-name>
    <res-type>javax.sql.DataSource</res-type>
    <res-auth>Container</res-auth>
  </resource-ref>
<% end; end %>

  <!-- jruby-rack-worker setup using the built-in libraries support : -->

  <context-param>
    <param-name>jruby.worker</param-name>
    <param-value>delayed_job</param-value> <!-- or resque (navvy) -->
  </context-param>

  <listener>
    <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
  </listener>

</web-app>
```

NOTE: on Warbler 1.4.x the .jar files from gems might no longer get packaged unless
configured to do so, assuming you only need the defaults and the worker jar, setup
a *config/warble.rb* file as follow :

```ruby
# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  # ...

  # Additional Java .jar files to include.  Note that if .jar files are placed
  # in lib (and not otherwise excluded) then they need not be mentioned here.
  # JRuby and JRuby-Rack are pre-loaded in this list.  Be sure to include your
  # own versions if you directly set the value
  # config.java_libs += FileList["lib/java/*.jar"]

  # If set to true, moves jar files into WEB-INF/lib.
  # Prior to version 1.4.2 of Warbler this was done by default.
  # But since 1.4.2 this config defaults to false.
  # Alternatively, this option can be set to a regular expression, which will
  # act as a jar selector -- only jar files that match the pattern will be
  # included in the archive.
  config.move_jars_to_webinf_lib = /jruby\-(core|stdlib|rack)/

  # Value of RAILS_ENV for the webapp -- default as shown below
  # config.webxml.rails.env = ENV['RAILS_ENV'] || 'production'

  #config.webxml.jruby.runtime.env = "DATABASE_URL=mysql://11.1.1.11/mydb\n" <<
  #      'PATH=/home/tomcat/bin:/usr/local/bin:/opt/bin,HOME="/home/tomcat"'
end
```

If you're deploying a Rails application on JRuby it's highly **recommended** to
uncomment `config.threadsafe!`. Otherwise, if unsure or you're code is not
thread-safe (yet), you'll end up polling several JRuby runtimes in a single process,
in this case however each worker thread will use and block an application runtime
from the pool (consider it while setting `jruby.min.runtimes` and `jruby.max.runtimes`).

### Trinidad

Trinidad provides you with an [extension][1] so you do not have to deal with XML.

### Custom Workers

There are a few gotchas to keep in mind when creating a custom worker, if you've
got a worker spawning script (e.g. a rake task) start there to write the worker
"starter" script. Some tips to keep in mind :

 * avoid native gems such as daemons (in DJ's case this means avoiding the whole
   `Delayed::Command` implementation)

 * remove command line processing - all your configuration should happen in an
   application initializer (or be configurable from *web.xml*)

 * make sure the worker code is thread-safe in case your application is running
   in `threadsafe!` mode (make sure no global state is changing by the worker or
   class variables are not being used to store worker state)

 * refactor your worker's exit code from a (process oriented) signal based `trap`
   to an `at_exit` hook - which respects the JRuby environment your workers are
   going to be running in

Keep in mind that if you do configure to use multiple threads the script will be
loaded and executed for each thread, thus move your worker class definition into
a separate file that you'll require from the script.

See the [Delayed::Job](/kares/jruby-rack-worker/tree/master/src/main/ruby/delayed)
JRuby "adapted" worker code for an inspiration.

If you'd like to specify custom parameters you can do so in the deployment
descriptor as context init parameters or as java system properties, use the
following code to obtain them :

```ruby
require 'jruby/rack/worker/env'
env = JRuby::Rack::Worker::ENV

worker = MyWorker.new
worker.queues = (env['QUEUES'] || 'all').split(',').map(&:strip)
worker.loop
```

If you need a logger JRuby-Rack-Worker sets up one which will be Rails.logger for
in Rails or a `STDOUT` logger otherwise by default :

```ruby
require 'jruby/rack/worker/logger'
begin
  worker = MyWorker.new
  worker.logger = JRuby::Rack::Worker.logger
  worker.start
rescue => e
  JRuby::Rack::Worker.log_error(e)
end
```


## Build

[JRuby](http://jruby.org) 1.6.8+ is required to build the project.

The build is performed by [rake](http://rake.rubyforge.org) which should be part
of your JRuby installation, if you're experiencing conflicts with another Ruby and
it's `rake` executable use `jruby -S rake` instead.
Besides you will need [ant](http://ant.apache.org/) installed for the Java part.

Build the *jruby-rack-worker_[VERSION].jar* using :

    rake jar

Build the gem (includes the .jar packaged) :

    rake gem


## Copyright

Copyright (c) 2016 [Karol Bucek](https://github.com/kares).
See LICENSE (http://www.apache.org/licenses/LICENSE-2.0) for details.

[0]: https://secure.travis-ci.org/kares/jruby-rack-worker.png
[1]: https://github.com/trinidad/trinidad_worker_extension
