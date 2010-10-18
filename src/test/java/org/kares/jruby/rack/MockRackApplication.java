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

import org.jruby.Ruby;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInitializationException;
import org.jruby.rack.RackResponse;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
class MockRackApplication implements RackApplication {

    private Ruby runtime;

    MockRackApplication(final Ruby runtime) {
        this.runtime = runtime;
    }

    public Ruby getRuntime() {
        if (runtime == null) {
            runtime = Ruby.newInstance();
        }
        return runtime;
    }

    public RackResponse call(RackEnvironment re) {
        throw new UnsupportedOperationException("call(RackEnvironment)");
    }

    public void destroy() {
        throw new UnsupportedOperationException("destroy()");
    }

    public void init() throws RackInitializationException {
        throw new UnsupportedOperationException("init()");
    }

}
