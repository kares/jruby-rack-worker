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

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.ThreadFactory;
import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;

import org.jruby.Ruby;
import org.jruby.rack.DefaultRackApplication;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackInitializationException;

import org.junit.Test;
import org.junit.Before;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
public class WorkerContextListenerTest {

    private WorkerContextListener target;

    @Before
    public void createTestTarget() {
        this.target = new WorkerContextListener();
    }

    @Test(expected = IllegalStateException.class)
    public void contextInitializedShouldFailAndLogIfThereIsNoRackApplicationFactory() {
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute("rack.factory") ).thenReturn( null );

        target.contextInitialized( newMockServletContextEvent(servletContext) );
        verify( servletContext ).log( startsWith("ERROR[" + WorkerContextListener.class.getName() + "]") );
    }

    @Test
    public void contextInitializedShouldWarnAndReturnIfThereIsNoWorkerScript()
        throws RackInitializationException {

        ServletContext servletContext = mock(ServletContext.class);
        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( new DefaultRackApplication() );
        when( servletContext.getAttribute("rack.factory") ).thenReturn( applicationFactory );

        target.contextInitialized( newMockServletContextEvent(servletContext) );

        verify( servletContext ).getInitParameter( WorkerContextListener.SCRIPT_KEY );
        verify( servletContext ).log( startsWith("WARN[" + WorkerContextListener.class.getName() + "]") );
    }

    @Test
    public void contextInitializedShouldNotWarnIfThereIsAWorkerScript()
        throws RackInitializationException {
        
        WorkerThreadFactory threadFactory = mockWorkerThreadFactory();
        when( threadFactory.newThread( any(Runnable.class) ) ).thenReturn( new Thread() );

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_KEY ) ).thenReturn( "puts 'hello kares !'" );

        target.contextInitialized( newMockServletContextEvent(servletContext) );
        
        verify( servletContext, never() ).log( startsWith("WARN[" + WorkerContextListener.class.getName() + "]") );
    }

    @Test
    public void contextInitializedShouldNotWarnIfThereIsAValidWorkerScriptPath()
        throws RackInitializationException, UnsupportedEncodingException {

        WorkerThreadFactory threadFactory = mockWorkerThreadFactory();
        when( threadFactory.newThread( any(Runnable.class) ) ).thenReturn( new Thread() );

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_PATH_KEY ) ).thenReturn( "/path/worker.rb" );
        InputStream inputStream = new ByteArrayInputStream( "nil".getBytes("UTF-8") );
        when( servletContext.getResourceAsStream("/path/worker.rb") ).thenReturn( inputStream );

        target.contextInitialized( newMockServletContextEvent(servletContext) );

        verify( servletContext, never() ).log( startsWith("WARN[" + WorkerContextListener.class.getName() + "]") );
    }

    @Test
    public void contextInitializedShouldStartASingleThreadByDefault()
        throws RackInitializationException {

        Thread thread = new Thread();
        WorkerThreadFactory threadFactory = mockWorkerThreadFactory();
        when( threadFactory.newThread( any(Runnable.class) ) ).thenReturn( thread );

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_KEY ) ).thenReturn( "nil" );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_PRIORITY_KEY ) ).thenReturn( null );

        target.contextInitialized( newMockServletContextEvent(servletContext) );
        assertTrue( thread.isAlive() );
    }

    @Test
    public void contextInitializedShouldCreateDaemonThreadWithContextNamePrefixAndConfiguredPriority()
        throws RackInitializationException {
        
        final List<Thread> newThreads = new ArrayList<Thread>();

        this.target = new WorkerContextListener() {

            @Override
            protected ThreadFactory newThreadFactory(ServletContext context) {
                return new MemoThreadFactory( super.newThreadFactory(context), newThreads );
            }

        };

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_KEY ) ).thenReturn( "nil" );
        when( servletContext.getServletContextName() ).thenReturn( "TheTestApp" );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_COUNT_KEY ) ).thenReturn( null );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_PRIORITY_KEY ) ).thenReturn( "7" );

        target.contextInitialized( newMockServletContextEvent(servletContext) );
        
        assertEquals( 1, newThreads.size() );
        Thread thread = newThreads.get(0);
        assertTrue( thread.isDaemon() );
        assertTrue( thread.getName().startsWith("TheTestApp") );
        assertEquals( 7, thread.getPriority() );
    }

    @Test
    public void contextInitializedShouldStartConfiguredAmountOfThreadsWithGivenPriority()
        throws RackInitializationException, UnsupportedEncodingException {

        final List<Thread> newThreads = new ArrayList<Thread>();

        this.target = new WorkerContextListener() {

            @Override
            protected ThreadFactory newThreadFactory(ServletContext context) {
                return new MemoThreadFactory( super.newThreadFactory(context), newThreads );
            }

        };

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_PATH_KEY ) ).thenReturn( "/path/worker.rb" );
        InputStream inputStream = new ByteArrayInputStream( "nil".getBytes("UTF-8") );
        when( servletContext.getResourceAsStream("/path/worker.rb") ).thenReturn( inputStream );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_COUNT_KEY ) ).thenReturn( "3" );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_PRIORITY_KEY ) ).thenReturn( "MIN" );

        target.contextInitialized( newMockServletContextEvent(servletContext) );

        assertEquals( 3, newThreads.size() );
        for ( Thread thread : newThreads ) {
            assertTrue( thread.isDaemon() );
            assertEquals( Thread.MIN_PRIORITY, thread.getPriority() );
        }
    }

    @Test
    public void contextDestroyedShouldDestroyAllStartedThreads1()
        throws RackInitializationException {

        final List<Thread> newThreads = new ArrayList<Thread>();

        this.target = new WorkerContextListener() {

            @Override
            protected ThreadFactory newThreadFactory(ServletContext context) {
                return new MemoThreadFactory( super.newThreadFactory(context), newThreads );
            }

        };

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_KEY ) ).thenReturn( "nil" );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_COUNT_KEY ) ).thenReturn( "2" );

        ServletContextEvent event = newMockServletContextEvent(servletContext);
        target.contextInitialized( event );
        
        target.contextDestroyed( event );

        for ( Thread thread : newThreads ) {
            assertFalse( thread.isAlive() );
        }
    }

    @Test
    public void contextDestroyedShouldDestroyAllStartedThreads2()
        throws RackInitializationException {

        final List<Thread> newThreads = new ArrayList<Thread>();

        this.target = new WorkerContextListener() {

            @Override
            protected ThreadFactory newThreadFactory(ServletContext context) {
                return new MemoThreadFactory( super.newThreadFactory(context), newThreads );
            }

        };

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_KEY ) ).thenReturn( "nil" );
        when( servletContext.getInitParameter( WorkerContextListener.THREAD_COUNT_KEY ) ).thenReturn( "3" );

        ServletContextEvent event = newMockServletContextEvent(servletContext);
        target.contextInitialized( event );

        // simulate at least some started running :
        while ( true ) {
            int size = newThreads.size();
            Thread.yield();
            if ( newThreads.get( new Random().nextInt(size) ).isAlive() ) {
                break;
            }
        }
        
        target.contextDestroyed( event );

        for ( Thread thread : newThreads ) {
            assertFalse( thread.isAlive() );
        }
    }

    @Test // an "integration" test
    public void contextInitializedSpawnsRubyExecutionInAThread()
        throws RackInitializationException {

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( servletContext.getInitParameter( WorkerContextListener.SCRIPT_KEY ) ).thenReturn( 
                "puts 'hello from JRuby worker'\n" +
                "require 'java'\n" +
                "Java::java::lang::System.setProperty('WorkerContextListenerTest', 'set_from_jruby')"
        );

        ServletContextEvent event = newMockServletContextEvent(servletContext);
        target.contextInitialized( event );

        final Thread worker = target.workers.values().iterator().next();
        while ( true ) {
            if ( ! worker.isAlive() ) break;
            Thread.yield();
        }

        assertEquals("set_from_jruby", System.getProperty("WorkerContextListenerTest"));
        System.clearProperty("WorkerContextListenerTest");
    }

    /**
     * =============================== Helpers ===============================
     */

    RackApplication newMockRackApplication(Ruby runtime)
        throws RackInitializationException {

        return new MockRackApplication(runtime);
    }

    RackApplicationFactory newMockRackApplicationFactory(RackApplication application)
            throws RackInitializationException {

        if (application == null) {
            application = newMockRackApplication(null);
        }
        return new MockRackApplicationFactory(application);
    }

    WorkerThreadFactory mockWorkerThreadFactory() {
        final WorkerThreadFactory threadFactory = mock(WorkerThreadFactory.class);
        this.target = new WorkerContextListener() {

            @Override
            protected ThreadFactory newThreadFactory(ServletContext context) {
                return threadFactory;
            }

        };
        return threadFactory;
    }

    MockServletContextEvent newMockServletContextEvent(ServletContext servletContext) {
        return new MockServletContextEvent(servletContext);
    }

}
