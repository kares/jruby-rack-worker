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

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ThreadFactory;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
class MemoThreadFactory implements ThreadFactory {

    private final ThreadFactory delegate;
    
    final List<Thread> returnedThreads;

    MemoThreadFactory(ThreadFactory delegate) {
        this.delegate = delegate;
        this.returnedThreads = new ArrayList<Thread>();
    }

    MemoThreadFactory(ThreadFactory delegate, List<Thread> returnedThreads) {
        this.delegate = delegate;
        this.returnedThreads = returnedThreads;
    }

    public Thread newThread(Runnable runnable) {
        Thread thread = delegate.newThread(runnable);
        returnedThreads.add( thread );
        return thread;
    }

}
