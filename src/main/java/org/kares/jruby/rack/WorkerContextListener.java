/*
 * Copyright (c) 2010 Karol Bucek
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

package org.kares.jruby.rack;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.util.ArrayList;
import java.util.Collection;
import java.util.concurrent.ThreadFactory;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackInitializationException;
import org.jruby.rack.RackServletContextListener;

/**
 * A context listener which spawns worker threads.
 *
 * @author kares <self_AT_kares_DOT_org>
 */
public class WorkerContextListener implements ServletContextListener {

    /**
     * The worker script to execute (should be a loop of some kind).
     * For scripts included in a separate file use {@link #SCRIPT_PATH_KEY}.
     *
     * <context-param>
     *   <param-name>jruby.worker.script</param-name>
     *   <param-value>require 'delayed/worker'; Delayed::Worker.new.start</param-value>
     * </context-param>
     */
    static final String SCRIPT_KEY = "jruby.worker.script";

    /**
     * Path to the worker script to be executed - the script will be parsed
     * and executed as a string thus don't rely on features such as __FILE__ !
     *
     * <context-param>
     *   <param-name>jruby.worker.script.path</param-name>
     *   <param-value>/lib/delayed/worker_loop.rb</param-value>
     * </context-param>
     */
    static final String SCRIPT_PATH_KEY = "jruby.worker.script.path";

    /**
     * The thread count - how many worker (daemon) threads to create.
     */
    static final String THREAD_COUNT_KEY = "jruby.worker.thread.count";

    /**
     * The thread priority - supported values: NORM, MIN, MAX and integers
     * between 1 - 10.
     */
    static final String THREAD_PRIORITY_KEY = "jruby.worker.thread.priority";
    

    private final Collection<Thread> workers = new ArrayList<Thread>(8);

    /**
     * @param event
     */
    public void contextInitialized(final ServletContextEvent event) {
        final ServletContext context = event.getServletContext();
        // JRuby-Rack :
        final RackApplicationFactory appFactory = (RackApplicationFactory)
                context.getAttribute(RackServletContextListener.FACTORY_KEY);
        if ( appFactory == null ) {
            final String message = 
                    RackApplicationFactory.class.getName() + " not yet initialized - " +
                    "seems this listener is executing before the " +
                    RackServletContextListener.class.getName() + "/RailsSevletContextListener !";
            context.log("ERROR[" + WorkerContextListener.class.getName() + "]: " + message);
            throw new IllegalStateException(message);
        }

        final String workerScript = getWorkerScript(context);
        if ( workerScript == null ) {
            final String message = "no worker script to execute - configure one using '" + SCRIPT_KEY + "' " +
                    "or '" + SCRIPT_PATH_KEY + "' context-param or see previous errors if already configured";
            context.log("WARN[" + WorkerContextListener.class.getName() + "]: " + message);
            return; //throw new IllegalStateException(message);
        }

        final int workersCount = getThreadCount(context);
        
        final ThreadFactory threadFactory = 
                new WorkerThreadFactory( context.getServletContextName(), getThreadPriority(context) );
        for ( int i = 0; i < workersCount; i++ ) {
            threadFactory.newThread(new Runnable() {
                public void run() {
                    try {
                        final RackApplication app = appFactory.getApplication();
                        app.getRuntime().evalScriptlet(workerScript);
                    }
                    catch (RackInitializationException e) {
                        context.log("ERROR[" + WorkerContextListener.class.getName() + "]: get rack application failed", e);
                    }
                }
            }).start();
        }
    }

    /**
     * @param event
     */
    public void contextDestroyed(final ServletContextEvent event) {
        //for ( final Thread worker : workers ) {
            //try {
                //worker.interrupt();
            //}
            //catch (Exception ignore) {}
        //}
        workers.clear();
    }

    private int getThreadCount(final ServletContext context) {
        String count = context.getInitParameter(THREAD_COUNT_KEY);
        try {
            if ( count != null ) return Integer.parseInt(count);
        }
        catch (NumberFormatException e) {
            context.log("WARN[" + WorkerContextListener.class.getName() + "] " +
                        "could not parse " + THREAD_COUNT_KEY + " parameter value = " + count, e);
        }
        return 1;
    }

    private int getThreadPriority(final ServletContext context) {
        String priority = context.getInitParameter(THREAD_PRIORITY_KEY);
        try {
            if ( priority != null ) {
                if ( "NORM".equalsIgnoreCase(priority) ) return Thread.NORM_PRIORITY;
                else if ( "MIN".equalsIgnoreCase(priority) ) return Thread.MIN_PRIORITY;
                else if ( "MAX".equalsIgnoreCase(priority) ) return Thread.MAX_PRIORITY;
                return Integer.parseInt(priority);
            }
        }
        catch (NumberFormatException e) {
            context.log("WARN[" + WorkerContextListener.class.getName() + "] " +
                        "could not parse " + THREAD_PRIORITY_KEY + " parameter value = " + priority, e);
        }
        return Thread.NORM_PRIORITY;
    }

    private String getWorkerScript(final ServletContext context) {
        String script = context.getInitParameter(SCRIPT_KEY);
        if ( script != null ) return script;

        script = context.getInitParameter(SCRIPT_PATH_KEY);
        if ( script != null ) {
            // INSPIRED BY DefaultRackApplicationFactory :
            final InputStream scriptStream = context.getResourceAsStream(script);
            if ( scriptStream != null ) {
                final StringBuilder str = new StringBuilder(256);
                try {
                    int c = scriptStream.read();
                    Reader reader; String coding = "UTF-8";
                    if (c == '#') {     // look for a coding: pragma
                        str.append((char) c);
                        while ((c = scriptStream.read()) != -1 && c != 10) {
                            str.append((char) c);
                        }
                        Matcher m = CODING.matcher(str.toString());
                        if (m.find()) coding = m.group(1);
                    }

                    str.append((char) c);
                    reader = new InputStreamReader(scriptStream, coding);

                    while ((c = reader.read()) != -1) {
                        str.append((char) c);
                    }
                }
                catch (Exception e) {
                    context.log("ERROR[" + WorkerContextListener.class.getName() + "] " +
                                "error reading script: '" + script + "'", e);
                    return null;
                }
                script = str.toString();
            }
        }

        return script;
    }

    private static final Pattern CODING = Pattern.compile("coding:\\s*(\\S+)");

}
