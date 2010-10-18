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

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
class MockServletContextEvent extends ServletContextEvent {

    private ServletContext servletContext;

    MockServletContextEvent(final ServletContext servletContext) {
        super(servletContext);
        this.servletContext = servletContext;
    }

    @Override
    public ServletContext getServletContext() {
        return servletContext;
    }

    @Override
    public Object getSource() {
        return getServletContext();
    }

}
