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

import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackInitializationException;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
class MockRackApplicationFactory implements RackApplicationFactory {

    private final RackApplication application;

    MockRackApplicationFactory(RackApplication application) {
        this.application = application;
    }

    public RackApplication getApplication() throws RackInitializationException {
        return application;
    }

    public RackApplication getErrorApplication() {
        throw new UnsupportedOperationException("getErrorApplication()");
    }

    public RackApplication newApplication() throws RackInitializationException {
        throw new UnsupportedOperationException("newApplication()");
    }

    public void init(RackContext rc) throws RackInitializationException {
        throw new UnsupportedOperationException("init(RackContext)");
    }

    public void destroy() {
        throw new UnsupportedOperationException("destroy()");
    }

    public void finishedWithApplication(RackApplication ra) {
        throw new UnsupportedOperationException("finishedWithApplication(RackApplication)");
    }

}
