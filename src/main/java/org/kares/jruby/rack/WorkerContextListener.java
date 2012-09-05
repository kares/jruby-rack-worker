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

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import org.kares.jruby.WorkerManager;

/**
 * A context listener that spawns worker threads.
 *
 * @author kares <self_AT_kares_DOT_org>
 */
public class WorkerContextListener implements ServletContextListener {
    
    private WorkerManager workerManager;

    /**
     * @param event
     */
    public void contextInitialized(final ServletContextEvent event) {
        getWorkerManager( event.getServletContext() ).startup();
    }

    /**
     * @param event
     */
    public void contextDestroyed(final ServletContextEvent event) {
        getWorkerManager( event.getServletContext() ).shutdown();
    }

    private WorkerManager getWorkerManager(final ServletContext context) {
        if (workerManager == null) {
            workerManager = new DefaultWorkerManager(context);
        }
        return workerManager;
    }

    void setWorkerManager(WorkerManager workerManager) {
        this.workerManager = workerManager;
    }
    
}
