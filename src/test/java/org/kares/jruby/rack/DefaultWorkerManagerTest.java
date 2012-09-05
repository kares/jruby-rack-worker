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
package org.kares.jruby.rack;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.util.Map;
import java.util.concurrent.ThreadFactory;

import javax.servlet.ServletContext;

import org.jruby.Ruby;

import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;

import org.kares.jruby.RubyWorker;
import org.kares.jruby.WorkerManager;
import org.kares.jruby.WorkerThreadFactory;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
public class DefaultWorkerManagerTest {

    private DefaultWorkerManagerImpl subject;
    
    static class DefaultWorkerManagerImpl extends DefaultWorkerManager {
        
        DefaultWorkerManagerImpl(final ServletContext context) {
            super(context);
        }
        
        //final Collection<Ruby> runtimes = new ArrayList<Ruby>();

        ThreadFactory threadFactory;
        
        @Override
        protected ThreadFactory newThreadFactory() {
            if ( threadFactory != null ) return threadFactory;
            return super.newThreadFactory();
        }
        
        void setThreadFactory(final ThreadFactory threadFactory) {
            this.threadFactory = threadFactory;
        }

        Map<RubyWorker, Thread> getWorkers() {
            return workers;
        }
        
    }
    
    @Before
    public void createSubject() {
        this.subject = new DefaultWorkerManagerImpl( mockServletContext() );
    }

    @Test(expected = IllegalStateException.class)
    public void failsToStartUpAndLogsIfThereIsNoRackApplicationFactory() {
        when( mockServletContext().getAttribute("rack.factory") ).thenReturn( null );
        when( mockServletContext().getInitParameter( "jruby.worker.script" ) ).thenReturn( "nil" );

        try {
            subject.startup();
        }
        finally {
            verify( mockServletContext() ).log( 
                    contains("org.jruby.rack.RackApplicationFactory not yet initialized") 
            ); 
        }
    }
    
    @Test
    public void startsUpWithRackFactoryAndWorkerScriptSet() {
        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( mockServletContext().getInitParameter( "jruby.worker.script" ) ).thenReturn( "nil" );

        subject.startup();

        verify( servletContext ).getInitParameter( "jruby.worker" );
        verify( servletContext ).getInitParameter( "jruby.worker.script" );
    }

    @Test
    public void startsUpWithRackFactoryAndWorkerScriptPathSet() throws UnsupportedEncodingException {
        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( mockServletContext().getInitParameter( "jruby.worker.script.path" ) ).thenReturn( "/path/worker.rb" );
        InputStream inputStream = new ByteArrayInputStream( "nil".getBytes("UTF-8") );
        when( mockServletContext().getResourceAsStream("/path/worker.rb") ).thenReturn( inputStream );
        
        subject.startup();

        verify( servletContext ).getInitParameter( "jruby.worker" );
        verify( servletContext ).getInitParameter( "jruby.worker.script" );
    }
    
    @Test
    public void usesRuntimeFromRackApplication() {
        final Ruby runtime = Ruby.newInstance();
        RackApplication application = newMockRackApplication( runtime );
        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( application );
        when( servletContext.getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        //when( mockServletContext().getInitParameter( "jruby.worker.script" ) ).thenReturn( "nil" );

        assertSame(runtime, subject.getRuntime());
    }
    

    @Test // an "integration" test
    public void spawnsRubyExecutionInAThread() throws InterruptedException {

        RackApplicationFactory applicationFactory = newMockRackApplicationFactory( null );
        when( mockServletContext().getAttribute( "rack.factory" ) ).thenReturn( applicationFactory );
        when( mockServletContext().getInitParameter( WorkerManager.SCRIPT_KEY ) ).thenReturn( 
                "puts 'hello from a jruby worker'\n" +
                "require 'java'\n" +
                "Java::JavaLang::System.setProperty('WorkerContextListenerTest', 'set_from_jruby')"
        );

        subject.startup();

        final Thread worker = subject.getWorkers().values().iterator().next();
        while ( true ) {
            if ( ! worker.isAlive() ) break;
            Thread.yield(); Thread.sleep(100);
        }

        assertEquals("set_from_jruby", System.getProperty("WorkerContextListenerTest"));
    }
    
    @After
    public void clearSystemProperty() {
        System.clearProperty("WorkerContextListenerTest");
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
    
    RackApplication newMockRackApplication(Ruby runtime) {
        return new MockRackApplication(runtime);
    }

    RackApplicationFactory newMockRackApplicationFactory(RackApplication application) {
        if (application == null) {
            application = newMockRackApplication(null);
        }
        return new MockRackApplicationFactory(application);
    }
    
}
