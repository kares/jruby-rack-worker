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

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.servlet.ServletContext;

import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.builtin.IRubyObject;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
public class ServletWorkerManagerTest {

    private ServletWorkerManagerImpl subject;
    
    static class ServletWorkerManagerImpl extends ServletWorkerManager {
        
        ServletWorkerManagerImpl(final ServletContext context) {
            super(context);
        }
        
        final Collection<Ruby> runtimes = new ArrayList<Ruby>();
        
        @Override
        protected Ruby getRuntime() {
            RubyInstanceConfig config = new RubyInstanceConfig();
            config.setUpdateNativeENVEnabled(false);
            String path = new File("src/test/resources/ruby_stubs").getAbsolutePath();
            config.setLoadPaths( Collections.singletonList(path) );
            
            final Ruby runtime = Ruby.newInstance(config);
            runtimes.add(runtime);
            return runtime;
        }

        ThreadFactory threadFactory;
        
        @Override
        protected ThreadFactory newThreadFactory() {
            if ( threadFactory != null ) return threadFactory;
            return super.newThreadFactory();
        }
        
        void setThreadFactory(final ThreadFactory threadFactory) {
            this.threadFactory = threadFactory;
        }
        
    }
    
    @Before
    public void createSubject() {
        this.subject = new ServletWorkerManagerImpl( mockServletContext() );
    }

    @After
    public void tearDownRuntimes() {
        if (subject != null) {
            for (Ruby runtime : subject.runtimes) {
                runtime.tearDown(false);
            }
        }
    }
    
    @Test
    public void startupWarnsIfTheresNoWorker() {
        when( mockServletContext().getInitParameter( "jruby.worker" ) ).thenReturn( null );
        
        subject.startup();
        
        verify( servletContext ).getInitParameter( "jruby.worker" );
        verify( servletContext ).getInitParameter( "jruby.worker.script" );
        
        verify( mockServletContext(), atLeastOnce() ).log( contains("no worker script to execute") );
    }
    
    @Test
    public void startupShouldNotWarnIfThereIsAWorkerConfigured1() throws UnsupportedEncodingException {
        when( mockServletContext().getInitParameter( "jruby.worker" ) ).thenReturn( "Delayed::Job" );

        subject.startup();

        verify( mockServletContext(), never() ).log( contains("no worker script to execute") );
    }

    @Test
    public void startupShouldNotWarnIfThereIsAWorkerConfigured2() throws UnsupportedEncodingException {
        when( mockServletContext().getInitParameter( "jruby.worker" ) ).thenReturn( "delayed_job" );

        subject.startup();

        verify( mockServletContext(), never() ).log( contains("no worker script to execute") );
    }

    @Test
    public void startupShouldNotWarnIfThereIsAWorkerScriptConfigured() {
        when( mockServletContext().getInitParameter( "jruby.worker.script" ) ).thenReturn( "puts 'hello kares'" );

        subject.startup();

        verify( mockServletContext(), never() ).log( contains("no worker script to execute") );
    }

    @Test
    public void startupShouldNotWarnIfThereIsAValidWorkerScriptPathConfigured() throws UnsupportedEncodingException {
        
        when( mockServletContext().getInitParameter( "jruby.worker.script.path" ) ).thenReturn( "/path/worker.rb" );
        InputStream inputStream = new ByteArrayInputStream( "nil".getBytes("UTF-8") );
        when( mockServletContext().getResourceAsStream("/path/worker.rb") ).thenReturn( inputStream );

        subject.startup();

        verify( mockServletContext(), never() ).log( contains("no worker script to execute") );
    }

    @Test
    public void startASingleThreadByDefault() throws InterruptedException {
        final AtomicBoolean started = new AtomicBoolean(false);
        final Thread thread = new Thread() {

            @Override
            public synchronized void start() {
                started.set(true);
                super.start();
            }
            
        };
        WorkerThreadFactory threadFactory = mockWorkerThreadFactory();
        when( threadFactory.newThread( any(Runnable.class) ) ).thenReturn( thread );
        subject.setThreadFactory(threadFactory);
        
        when( mockServletContext().getInitParameter( "jruby.worker.script" ) ).thenReturn( "nil" );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_PRIORITY_KEY ) ).thenReturn( null );

        subject.startup();
        
        Thread.sleep(10);
        
        verify( threadFactory, times(1) ).newThread( any(Runnable.class) );
        assertTrue( started.get() ); //assertTrue( thread.isAlive() );
    }

    @Test
    public void startsDaemonThreadWithContextNamePrefixAndConfiguredPriority() {
        when( mockServletContext().getServletContextName() ).thenReturn( "TheTestApp" );
        when( mockServletContext().getInitParameter( "jruby.worker.script" ) ).thenReturn( "nil" );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_COUNT_KEY ) ).thenReturn( null );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_PRIORITY_KEY ) ).thenReturn( "7" );

        createSubject();
        
        final List<Thread> createdThreads = new ArrayList<Thread>();
        ThreadFactory threadFactory = subject.newThreadFactory();
        threadFactory = new MemoThreadFactory( threadFactory, createdThreads );
        
        subject.setThreadFactory(threadFactory);
        
        subject.startup();
        
        assertEquals( 1, createdThreads.size() );
        Thread thread = createdThreads.get(0);
        assertTrue( thread.isDaemon() );
        assertTrue( "thread-name: " + thread.getName(), thread.getName().startsWith("TheTestApp") );
        assertEquals( 7, thread.getPriority() );
    }

    @Test
    public void startsConfiguredAmountOfThreadsWithGivenPriority() throws UnsupportedEncodingException {
        when( mockServletContext().getInitParameter( "jruby.worker.script.path" ) ).thenReturn( "/path/worker.rb" );
        InputStream inputStream = new ByteArrayInputStream( "nil".getBytes("UTF-8") );
        when( mockServletContext().getResourceAsStream("/path/worker.rb") ).thenReturn( inputStream );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_COUNT_KEY ) ).thenReturn( "3" );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_PRIORITY_KEY ) ).thenReturn( "MIN" );

        createSubject();
        
        final List<Thread> createdThreads = new ArrayList<Thread>();
        ThreadFactory threadFactory = subject.newThreadFactory();
        threadFactory = new MemoThreadFactory( threadFactory, createdThreads );
        
        subject.setThreadFactory(threadFactory);
        
        subject.startup();

        assertEquals( 3, createdThreads.size() );
        for ( Thread thread : createdThreads ) {
            assertTrue( thread.isDaemon() );
            assertEquals( Thread.MIN_PRIORITY, thread.getPriority() );
        }
    }

    @Test
    public void stopsAllStartedThreads1() {
        when( mockServletContext().getServletContextName() ).thenReturn( "TheTestApp" );
        when( mockServletContext().getInitParameter( WorkerManager.SCRIPT_KEY ) ).thenReturn( "nil" );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_COUNT_KEY ) ).thenReturn( "2" );

        createSubject();
        
        final List<Thread> createdThreads = new ArrayList<Thread>();
        ThreadFactory threadFactory = subject.newThreadFactory();
        threadFactory = new MemoThreadFactory( threadFactory, createdThreads );
        
        subject.setThreadFactory(threadFactory);
        
        subject.startup();
        
        //Thread.yield();
        
        subject.shutdown();

        for ( Thread thread : createdThreads ) {
            assertFalse( thread.isAlive() );
        }
    }

    @Test
    public void stopsAllStartedThreads2() throws InterruptedException {
        when( mockServletContext().getInitParameter( WorkerManager.SCRIPT_KEY ) ).thenReturn( "sleep(0.1)" );
        when( mockServletContext().getInitParameter( WorkerManager.THREAD_COUNT_KEY ) ).thenReturn( "3" );

        createSubject();
        
        final List<Thread> createdThreads = new ArrayList<Thread>();
        ThreadFactory threadFactory = subject.newThreadFactory();
        threadFactory = new MemoThreadFactory( threadFactory, createdThreads );
        
        subject.setThreadFactory(threadFactory);

        subject.startup();
        
        Thread.sleep(500);
        
        subject.shutdown();

        for ( Thread thread : createdThreads ) {
            assertFalse( thread.isAlive() );
        }
    }

    @Test
    public void exportedItselfIntoTheRuntime() throws UnsupportedEncodingException {
        when( mockServletContext().getInitParameter( WorkerManager.SCRIPT_KEY ) ).thenReturn( "nil" );
        
        subject.setExported(true);
        subject.startup();

        RubyWorker worker = subject.workers.keySet().iterator().next();
        IRubyObject workerManagerProxy = worker.runtime.evalScriptlet("$worker_manager");
        assertNotNull("$worker_manager not exported", workerManagerProxy);
        Object workerManager = JavaEmbedUtils.rubyToJava(workerManagerProxy);
        assertEquals(subject, workerManager);
    }
    
    /**
     * =============================== Helpers ===============================
     */

    private WorkerThreadFactory workerThreadFactory;
    
    WorkerThreadFactory mockWorkerThreadFactory() {
        if (workerThreadFactory == null) {
            workerThreadFactory = mock(WorkerThreadFactory.class);
        }
        return workerThreadFactory;
    }

    private ServletContext servletContext;
    
    ServletContext mockServletContext() {
        if (servletContext == null) {
            servletContext = mock(ServletContext.class);
        }
        return servletContext;
    }
    
}
