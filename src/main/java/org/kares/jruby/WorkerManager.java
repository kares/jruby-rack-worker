/*
 * Copyright (c) 2012 Karol Bucek
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.kares.jruby;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ThreadFactory;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.jruby.Ruby;
import org.jruby.javasupport.JavaEmbedUtils;

/**
 * Manages JRuby worker threads.
 *
 * Requires {@link #getRuntime()} to be implemented.
 *
 * @author kares <self_AT_kares_DOT_org>
 */
public abstract class WorkerManager {

    /**
     * The built-in worker to use.
     *
     * <context-param>
     *   <param-name>jruby.worker</param-name>
     *   <param-value>Delayed::Job</param-value>
     * </context-param>
     */
    public static final String WORKER_KEY = "jruby.worker";

    /**
     * The worker script to execute (should be a loop of some kind).
     * For scripts included in a separate file use {@link #SCRIPT_PATH_KEY}.
     *
     * <context-param>
     *   <param-name>jruby.worker.script</param-name>
     *   <param-value>
     *      require 'delayed/jruby_worker'
     *      Delayed::JRubyWorker.new(:quiet => false).start
     *   </param-value>
     * </context-param>
     */
    public static final String SCRIPT_KEY = "jruby.worker.script";

    /**
     * Path to the worker script to be executed - the script will be parsed
     * and executed as a string thus don't rely on features such as __FILE__ !
     *
     * <context-param>
     *   <param-name>jruby.worker.script.path</param-name>
     *   <param-value>lib/delayed/jruby_worker.rb</param-value>
     * </context-param>
     */
    public static final String SCRIPT_PATH_KEY = "jruby.worker.script.path";

    /**
     * The thread count - how many worker (daemon) threads to create.
     */
    public static final String THREAD_COUNT_KEY = "jruby.worker.thread.count";

    /**
     * The thread priority - supported values: NORM, MIN, MAX and integers
     * between 1 - 10.
     */
    public static final String THREAD_PRIORITY_KEY = "jruby.worker.thread.priority";

    /**
     * <b></>-Djruby.worker.skip=true</b> will skip worker startup.
     */
    public static final String SKIP_KEY = "jruby.worker.skip";

    /**
     * By default a WorkerManager instance is exported with it's Ruby runtime.
     * This is very useful to resolve configuration keys per runtime the same
     * way the manager does (using {@link #getParameter(java.lang.String)}).
     * check-out <code>jruby/rack/worker/env.rb</code>
     */
    protected static final String EXPORTED_NAME = "worker_manager";
    private static final String GLOBAL_VAR_NAME = '$' + EXPORTED_NAME;

    private boolean exported = true;

    protected final Map<RubyWorker, Thread> workers = new HashMap<RubyWorker, Thread>(4);

    /**
     * Startup all workers.
     */
    public void startup() {
        if ( isSkipStartup() ) {
            log("[" + getClass().getName() + "] startup skipped"); return;
        }

        final String[] workerScript = getWorkerScript(); // [ script, fileName ]

        if ( workerScript == null ) {
            final String message = "no worker script to execute - configure one using '" + SCRIPT_KEY + "' " +
                    "or '" + SCRIPT_PATH_KEY + "' parameter (or see previous errors if already configured) ";
            log("[" + getClass().getName() + "] " + message + " !");
            return; // throw new IllegalStateException(message);
        }

        final int workersCount = getThreadCount();

        final ThreadFactory threadFactory = newThreadFactory();
        for ( int i = 0; i < workersCount; i++ ) {
            final Ruby runtime;
            try {
                runtime = getRuntime(); // handles DefaultErrorApplication.getRuntime
            }
            catch (UnsupportedOperationException e) { // error happened during JRuby-Rack startup
                log("[" + getClass().getName() + "] failed to obtain (Ruby) runtime");
                break;
            }

            if ( isExported() ) {
                runtime.getGlobalVariables().set(GLOBAL_VAR_NAME, JavaEmbedUtils.javaToRuby(runtime, this));
            }
            try {
                final RubyWorker worker = newRubyWorker(runtime, workerScript[0], workerScript[1]);
                final Thread workerThread = threadFactory.newThread(worker);
                workers.put(worker, workerThread);
                workerThread.start();
            }
            catch (Exception e) {
                log("[" + getClass().getName() + "] worker startup failed", e);
                break;
            }
        }
        log("[" + getClass().getName() + "] started " + workers.size() + " worker(s)");
    }

    /**
     * Shutdown all (managed) workers.
     */
    public void shutdown() {
        final Map<RubyWorker, Thread> workers = new HashMap<RubyWorker, Thread>(this.workers);
        this.workers.clear();
        for ( final RubyWorker worker : workers.keySet() ) {
            if ( isExported() ) {
                worker.runtime.getGlobalVariables().clear(GLOBAL_VAR_NAME);
            }
            final Thread workerThread = workers.get(worker);
            try {
                worker.stop();
                // JRuby seems to ignore Java's interrupt arithmentic
                // @see http://jira.codehaus.org/browse/JRUBY-4135
                workerThread.interrupt();
                workerThread.join(1000);
            }
            catch (InterruptedException e) {
                log("[" + getClass().getName() + "] interrupted");
                Thread.currentThread().interrupt();
            }
            catch (Exception e) {
                log("[" + getClass().getName() + "] ignoring exception " + e);
            }
        }
        /*
        try { Thread.sleep(1000); } // Tomcat is just too fast with it's thread detection !
        catch (InterruptedException e) {
            // SEVERE: The web application [/] appears to have started a thread named [worker_1]
            // but has failed to stop it. This is very likely to create a memory leak.
            context.log("[" + WorkerContextListener.class.getName() + "] ignoring interrupt " + e);
        } */
        log("[" + getClass().getName() + "] stopped " + workers.size() + " worker(s)");
    }

    /**
     * This shall be implemented by concrete classes and should return an
     * (initialized) JRuby runtime ready to be used by a worker.
     *
     * By default this method is expected to be called as many times as the
     * configured worker count, thus shall return the same runtime only if
     * it's thread-safe !
     * @return a Ruby runtime
     */
    protected abstract Ruby getRuntime() ;

    // ----------------------------------------
    // properties
    // ----------------------------------------

    private String threadPrefix;

    public String getThreadPrefix() {
        return threadPrefix;
    }

    public void setThreadPrefix(String threadPrefix) {
        this.threadPrefix = threadPrefix;
    }

    private Integer threadCount;

    public Integer getThreadCount() {
        if (threadCount == null) {
            String count = getParameter(THREAD_COUNT_KEY);
            try {
                if ( count != null ) {
                    return threadCount = Integer.parseInt(count);
                }
            }
            catch (NumberFormatException e) {
                log("[" + getClass().getName() + "] " +
                    "could not parse " + THREAD_COUNT_KEY + " parameter value = " + count, e);
            }
            threadCount = 1;
        }
        return threadCount;
    }

    public void setThreadCount(Integer threadCount) {
        this.threadCount = threadCount;
    }

    private Integer threadPriority;

    public Integer getThreadPriority() {
        if (threadPriority == null) {
            String priority = getParameter(THREAD_PRIORITY_KEY);
            try {
                if ( priority != null ) {
                    if ( "NORM".equalsIgnoreCase(priority) )
                        return threadPriority = Thread.NORM_PRIORITY;
                    else if ( "MIN".equalsIgnoreCase(priority) )
                        return threadPriority = Thread.MIN_PRIORITY;
                    else if ( "MAX".equalsIgnoreCase(priority) )
                        return threadPriority = Thread.MAX_PRIORITY;
                    return threadPriority = Integer.parseInt(priority);
                }
            }
            catch (NumberFormatException e) {
                log("[" + getClass().getName() + "] " +
                    "could not parse " + THREAD_PRIORITY_KEY + " parameter value = '" + priority + "'");
            }
            threadPriority = Thread.NORM_PRIORITY;
        }
        return threadPriority;

    }

    public void setThreadPriority(Integer threadPriority) {
        this.threadPriority = threadPriority;
    }

    /**
     * Get the worker script/file to execute.
     * @param context
     * @return a script, fileName tuple
     */
    public String[] getWorkerScript() {
        String worker = getParameter(WORKER_KEY);
        if ( worker != null ) {
            String script = getAvailableWorkers().get( worker.replace("::", "_").toLowerCase() );
            if ( script != null ) {
                return new String [] { null, script };
            }
            else {
                log("[" + getClass().getName() + "] unsupported worker name: '" + worker + "' !");
            }
        }

        String script = getParameter(SCRIPT_KEY);
        if ( script != null ) return new String [] { script, null };

        String scriptPath = getParameter(SCRIPT_PATH_KEY);
        if ( scriptPath == null ) return null;
        // INSPIRED BY DefaultRackApplicationFactory :
        try {
            final InputStream scriptStream = openPath(scriptPath);
            if ( scriptStream != null ) {
                final StringBuilder content = new StringBuilder(256);
                int c = scriptStream.read();
                Reader reader; String coding = "UTF-8";
                if ( c == '#' ) { // look for a coding: pragma
                    content.append((char) c);
                    while ((c = scriptStream.read()) != -1 && c != 10) {
                        content.append((char) c);
                    }
                    Pattern matchCoding = Pattern.compile("coding:\\s*(\\S+)");
                    Matcher matcher = matchCoding.matcher( content.toString() );
                    if (matcher.find()) coding = matcher.group(1);
                }

                content.append((char) c);
                reader = new InputStreamReader(scriptStream, coding);

                while ((c = reader.read()) != -1) {
                    content.append((char) c);
                }

                script = content.toString();
            }
        }
        catch (Exception e) {
            log("[" + getClass().getName() + "] error reading script: '" + scriptPath + "'", e);
            return null;
        }

        return new String[] { script, scriptPath }; // one of these is != null
    }

    public Map<String, String> getAvailableWorkers() {
        return new HashMap<String, String>() {

            {
                put("delayed_job", "delayed/start_worker.rb");
                put("delayed", "delayed/start_worker.rb"); // alias
                put("navvy", "navvy/start_worker.rb");
                put("resque", "resque/start_worker.rb");
            }

        };
    }

    protected boolean isSkipStartup() {
        return Boolean.parseBoolean(getParameter(SKIP_KEY));
    }

    /**
     * @return whether to export this manager instance to the Ruby runtime
     */
    public boolean isExported() {
        return exported;
    }

    /**
     * Only applies if called before {@link #startup()}.
     * @see #isExported()
     * @param exported
     */
    public void setExported(final boolean exported) {
        this.exported = exported;
    }

    // ----------------------------------------
    // overridables
    // ----------------------------------------

    protected RubyWorker newRubyWorker(final Ruby runtime, final String script, final String fileName) {
        return new RubyWorker(runtime, script, fileName);
    }

    protected ThreadFactory newThreadFactory() {
        return new WorkerThreadFactory( getThreadPrefix(), getThreadPriority() );
    }

    public String getParameter(final String key) {
        return System.getProperty(key);
    }

    protected InputStream openPath(final String path) throws IOException {
        try {
            return new URL(path).openStream();
        }
        catch (MalformedURLException e) {
            final File file = new File(path);
            if ( file.exists() && file.isFile() ) {
                return new FileInputStream(file);
            }
        }
        return null;
    }

    protected void log(final String message) {
        System.out.println(message);
    }

    protected void log(final String message, final Exception e) {
        System.err.println(message);
        e.printStackTrace(System.err);
    }

}
