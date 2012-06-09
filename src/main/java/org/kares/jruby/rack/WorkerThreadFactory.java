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

import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * A thread factory producing worker threads.
 *
 * @author kares <self_AT_kares_DOT_org>
 */
public class WorkerThreadFactory implements ThreadFactory {

    /**
     * Thread name identifier, all threads created with this factory
     * contain the given identifier.
     */
    public static final String NAME_ID = "jruby-rack-worker_";
    
    static final AtomicInteger threadCount = new AtomicInteger(1);

    private final String prefix;

    private final int priority;

    private final ThreadGroup group;

    public WorkerThreadFactory(final String prefix, final int priority) {
        this.priority = priority;
        this.prefix = ( prefix == null || prefix.length() == 0 ) ? "" : prefix + '-';
        final SecurityManager securityManager = System.getSecurityManager();
        group = ( securityManager != null ) ?
                    securityManager.getThreadGroup() :
                        Thread.currentThread().getThreadGroup();
    }

    public Thread newThread(final Runnable task) {
        final String threadName = prefix + NAME_ID + threadCount.getAndIncrement();
        final Thread thread = new Thread(group, task, threadName, 0);
        if ( ! thread.isDaemon() ) thread.setDaemon(true);
        if ( thread.getPriority() != priority ) thread.setPriority(priority);
        return thread;
    }

}
