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

import java.util.concurrent.atomic.AtomicBoolean;
import javax.servlet.ServletContext;

import org.jruby.Ruby;

import org.kares.jruby.*;

import org.junit.Test;
import org.junit.Before;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
public class WorkerContextListenerTest {

    private WorkerContextListener subject;

    @Before
    public void createTestTarget() {
        this.subject = new WorkerContextListener();
    }

    @Test
    public void contextInitializedStartsUpWorkerManager() {
        final AtomicBoolean startup = new AtomicBoolean(false);
        final AtomicBoolean shutdown = new AtomicBoolean(false);
        
        subject.setWorkerManager(new WorkerManager() {
            
            @Override
            public void startup() {
                startup.set(true);
            }

            @Override
            public void shutdown() {
                shutdown.set(true);
            }

            @Override
            protected Ruby getRuntime() {
                throw new UnsupportedOperationException("getRuntime()");
            }
            
        });
        
        final ServletContext servletContext = mock(ServletContext.class);
        subject.contextInitialized( newMockServletContextEvent(servletContext) );
        
        assertTrue( startup.get() );
        assertFalse( shutdown.get() );
    }

    @Test
    public void contextDestroyedShutsDownWorkerManager() {
        final AtomicBoolean startup = new AtomicBoolean(false);
        final AtomicBoolean shutdown = new AtomicBoolean(false);
        
        subject.setWorkerManager(new WorkerManager() {
            
            @Override
            public void startup() {
                startup.set(true);
            }

            @Override
            public void shutdown() {
                shutdown.set(true);
            }

            @Override
            protected Ruby getRuntime() {
                throw new UnsupportedOperationException("getRuntime()");
            }
            
        });
        
        final ServletContext servletContext = mock(ServletContext.class);
        subject.contextDestroyed( newMockServletContextEvent(servletContext) );
        
        assertFalse( startup.get() );
        assertTrue( shutdown.get() );
    }

    @Test(expected = IllegalStateException.class)
    public void contextInitializedShouldFailIfThereIsNoRackApplicationFactory() {
        ServletContext servletContext = mock(ServletContext.class);
        when( servletContext.getAttribute("rack.factory") ).thenReturn( null );
        when( servletContext.getInitParameter( "jruby.worker.script" ) ).thenReturn( "nil" );

        subject.contextInitialized( newMockServletContextEvent(servletContext) );
    }
    
    /**
     * =============================== Helpers ===============================
     */

    MockServletContextEvent newMockServletContextEvent(ServletContext servletContext) {
        return new MockServletContextEvent(servletContext);
    }
    
}
