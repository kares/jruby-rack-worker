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
public class MemoThreadFactory implements ThreadFactory {

    private final ThreadFactory delegate;
    
    final List<Thread> newThreads;

    MemoThreadFactory(final ThreadFactory delegate) {
        this.delegate = delegate;
        this.newThreads = new ArrayList<Thread>();
    }

    MemoThreadFactory(final ThreadFactory delegate, final List<Thread> newThreads) {
        this.delegate = delegate;
        this.newThreads = newThreads;
    }

    public Thread newThread(Runnable runnable) {
        Thread thread = delegate.newThread(runnable);
        newThreads.add( thread );
        return thread;
    }

}
