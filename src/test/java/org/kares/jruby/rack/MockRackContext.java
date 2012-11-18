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

import java.io.OutputStream;
import java.io.PrintStream;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackContext;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
public class MockRackContext implements RackContext {

    private RackConfig config;
    
    public RackConfig getConfig() {
        if (config == null) {
            throw new IllegalStateException("no config");
        }
        return config;
    }

    public void setConfig(RackConfig config) {
        this.config = config;
    }
    
    public String getServerInfo() {
        return getClass().getName();
    }

    public void log(String msg) {
        log(INFO, msg);
    }

    public void log(String msg, Throwable e) {
        log(ERROR, msg, e);
    }

    public void log(String level, String msg) {
        doLog(level, msg, null);
    }

    public void log(String level, String msg, Throwable e) {
        doLog(level, msg, e);
    }

    private PrintStream log = System.out;
    
    void doLog(String level, String msg, Throwable e) {
        log.println("[" + level + "] " + msg + "");
        if (e != null) {
            e.printStackTrace(log);
        }
    }

    PrintStream getLog() {
        return log;
    }

    void setLog(PrintStream log) {
        this.log = log;
    }

    void setLog(OutputStream out) {
        this.log = new PrintStream(out);
    }
    
}
