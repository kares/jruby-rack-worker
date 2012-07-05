# JRuby Rack Worker

Thread based workers on top of [jruby-rack](http://github.com/jruby/jruby-rack).

With out of the box [JRuby](http://jruby.org) "adapters" for: 

* [Resque](http://github.com/defunkt/resque) (**COMING SOON**)
* [Delayed::Job](http://github.com/collectiveidea/delayed_job)
* [Navvy](http://github.com/jeffkreeftmeijer/navvy) 

... but one can easily write/adapt his own worker loop.


## Motivation

Ruby attempts to stay pretty close to UNIX and most popular workers have been 
modeled the spawn a background process way. [JRuby](http://jruby.org) brings 
Java to the table, where "Young Java Knights" are thought to use threads 
whenever in a need to compute something parallel while serving requests.

There's no right or wrong way of doing this. If you do expect chaos like Resque
proclaims - have long running jobs that consume a lot of memory they have trouble 
releasing (e.g. due C extensions) run a separate process for sure.
But otherwise (after all C exts usually have a native Java alternative on JRuby) 
having predictable thread-safely written workers, one should be fine with 
running them concurrently as part of the application in a daemon thread.

This does have the advantage of keeping the deployment simple and saving some
precious memory (most notably with `threadsafe!` mode) that would have been 
eaten by the separate process. Besides, your application might warm up faster 
and start benefiting from JRuby's runtime optimalizations slightly sooner ...

On the other hand your jobs should be fairly simple and complete "fast" (in a 
rate of seconds rather than several minutes or hours) as they will live and 
restart with the lifecycle of the deployed application and application server.


## Setup

Copy the `jruby-rack-worker.jar` into the `lib` folder or the directory being
mapped to `WEB-INF/lib` e.g. `lib/java`.

Configure the worker in `web.xml`, you'll need to add a servlet context listener
that will start threads when your application boots and a script to be executed
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

The `WorkerContextListener` needs to be executed (and thus configured) after the 
`RailsServletContextListener`/`RackServletContextListener` as it expects the 
*jruby-rack* environment to be available.

Sample deployment descriptor including optional parameters:
[web.xml](/kares/jruby-rack-worker/blob/master/src/test/resources/sample.web.xml).

### Warbler

If you're using [Warbler](http://caldersphere.rubyforge.org/warbler) to assemble
your application you might simply declare a gem dependency with Bundler as your
gems will be scanned for jars and packaged correctly:

    gem 'jruby-rack-worker', :platform => :jruby, :require => nil

Otherwise copy the jar into your *warble.rb* configured `config.java_libs`.

Warbler checks for a *config/web.xml.erb* thus configure the worker there, e.g. :

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
        <param-value>delayed_job</param-value> <!-- or resque or navvy -->
      </context-param>

      <listener>
        <listener-class>org.kares.jruby.rack.WorkerContextListener</listener-class>
      </listener>

    </web-app>


If you're deploying a Rails application on JRuby it's highly **recommended** to 
uncomment `config.threadsafe!`. Otherwise, if unsure or you're code is not 
thread-safe yet you'll end up polling several JRuby runtimes in a single process, 
in this case however each worker thread will use (block) an application runtime 
from the pool (consider it while setting 
`jruby.min.runtimes` and `jruby.max.runtimes` parameters).


### Custom Workers

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


## Build

[JRuby](http://jruby.org) 1.5+ is required to build the project.
The build is performed by [rake](http://rake.rubyforge.org) which should be part
of your JRuby installation, if you're experiencing conflicts with another Ruby and
it's rake executable use `jruby -S rake` instead of the bare `rake` command.
Besides you'll to need [ant](http://ant.apache.org/) installed for the Java part.

Build the `jruby-rack-worker.jar` using :

    rake jar

Build the gem (with the jar packaged) :

    rake gem

