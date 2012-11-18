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

import org.jruby.Ruby;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackException;
import org.jruby.rack.RackLogger;
import org.kares.jruby.ServletWorkerManager;

/**
 * Default worker manager implemented on top of JRuby-Rack.
 * 
 * @author kares <self_AT_kares_DOT_org>
 */
public class DefaultWorkerManager extends ServletWorkerManager {
    
    public DefaultWorkerManager(final ServletContext context) {
        super(context);
    }

    @Override
    public Ruby getRuntime() throws IllegalStateException, UnsupportedOperationException {
        // obtain JRuby runtime from JRuby-Rack :
        final RackApplicationFactory appFactory = getRackFactory();
        if ( appFactory == null ) {
            final String message = 
                    RackApplicationFactory.class.getName() + " not yet initialized - " +
                    "seems this listener is executing before the " +
                    "RackServletContextListener / RailsSevletContextListener !";
            log("[" + getClass().getName() + "] " + message);
            throw new IllegalStateException(message);
        }
        final RackApplication app;
        try {
            app = appFactory.getApplication();
        }
        catch (RackException e) {
            throw new UnsupportedOperationException(e); // rack/rails initialization failure
        }
        if ( app == null ) {
            throw new IllegalStateException("factory returned null app");
        }
        if ( app.getClass().getName().indexOf("ErrorApplication") != -1 ) {
            throw new UnsupportedOperationException("won't use error application runtime");
        }
        return app.getRuntime();
    }
    
    protected RackContext getRackContext() {
        return (RackContext) getServletContext().
            getAttribute( RackApplicationFactory.RACK_CONTEXT );
    }

    protected RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory) getServletContext().
            getAttribute( RackApplicationFactory.FACTORY );
    }
    
    private RackLogger logger;

    public RackLogger getLogger() {
        if (logger == null) {
            synchronized (this) {
                if (logger == null) {
                    logger = getRackContext();
                }
            }
        }
        return logger;
    }

    public synchronized void setLogger(RackLogger logger) {
        this.logger = logger;
    }
    
    @Override
    protected void log(String message) {
        final RackLogger logger = getLogger();
        if (logger != null) {
            logger.log(RackLogger.INFO, message);
        }
        else {
            super.log(message);
        }
    }

    @Override
    protected void log(String message, Exception e) {
        final RackLogger logger = getLogger();
        if (logger != null) {
            logger.log(RackLogger.ERROR, message, e);
        }
        else {
            super.log(message, e);
        }
    }
    
}
