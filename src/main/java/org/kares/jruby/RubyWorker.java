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

import org.jruby.Ruby;

/**
 * Ruby (JRuby) worker.
 *
 * @author kares <self_AT_kares_DOT_org>
 */
public class RubyWorker implements Runnable {

    protected final Ruby runtime;
    protected final String script;
    protected final String fileName;

    public RubyWorker(final Ruby runtime, final String script) {
        this(runtime, script, null);
    }

    public RubyWorker(final Ruby runtime, final String script, final String fileName) {
        this.runtime = runtime;
        this.script = script;
        this.fileName = fileName;
    }

    public void run() {
        if ( fileName == null ) {
            runtime.evalScriptlet(script);
        }
        else if ( script == null ) {
            // try loading the script using ruby :
            runtime.evalScriptlet("load '" + fileName + "'");
        }
        else {
            runtime.executeScript(script, fileName);
        }
    }

    public void stop() {
        // @TODO jruby-rack manages the runtimes thus let it terminate !?
        if ( true ) runtime.tearDown();
    }

}
