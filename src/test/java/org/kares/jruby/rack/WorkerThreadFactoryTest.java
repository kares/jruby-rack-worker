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

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * @author kares <self_AT_kares_DOT_org>
 */
public class WorkerThreadFactoryTest {

    @Test
    public void shouldCreateNewThreadsOnEachNewThreadCall() {
        WorkerThreadFactory factory = new WorkerThreadFactory("", 1);
        Runnable dummy = new Runnable() { public void run() { return; } };
        Thread thread1 = factory.newThread(dummy);
        Thread thread2 = factory.newThread(dummy);
        Thread thread3 = factory.newThread(dummy);

        assertNotNull(thread1);
        assertNotNull(thread2);
        assertNotNull(thread3);
        assertNotSame(thread1, thread2);
        assertNotSame(thread2, thread3);
        assertNotSame(thread3, thread1);
    }

    @Test
    public void shouldCreateNewThreadsWithDifferentNames1() {
        WorkerThreadFactory factory = new WorkerThreadFactory("xxx", 1);
        Runnable dummy = new Runnable() { public void run() { return; } };
        Thread thread1 = factory.newThread(dummy);
        Thread thread2 = factory.newThread(dummy);
        Thread thread3 = factory.newThread(dummy);

        assertNotNull(thread1.getName());
        assertNotNull(thread2.getName());
        assertNotNull(thread3.getName());

        assertFalse( thread1.getName().equals(thread2.getName()) );
        assertFalse( thread2.getName().equals(thread3.getName()) );
        assertFalse( thread3.getName().equals(thread1.getName()) );
    }

    @Test
    public void shouldCreateNewThreadsWithDifferentNames2() {
        WorkerThreadFactory factory = new WorkerThreadFactory(null, 1);
        Runnable dummy = new Runnable() { public void run() { return; } };
        Thread thread1 = factory.newThread(dummy);
        Thread thread2 = factory.newThread(dummy);
        Thread thread3 = factory.newThread(dummy);

        assertNotNull(thread1.getName());
        assertNotNull(thread2.getName());
        assertNotNull(thread3.getName());

        assertFalse( thread1.getName().equals(thread2.getName()) );
        assertFalse( thread2.getName().equals(thread3.getName()) );
        assertFalse( thread3.getName().equals(thread1.getName()) );
    }

    @Test
    public void newThreadsShouldHaveTheGivenPriority() {
        WorkerThreadFactory factory = new WorkerThreadFactory(null, 2);
        Thread thread = factory.newThread(new Runnable() {

            public void run() { return; }

        });
        assertNotNull(thread);
        assertEquals(2, thread.getPriority());
    }

    @Test
    public void newThreadsShouldBeSetToDaemon() {
        WorkerThreadFactory factory = new WorkerThreadFactory(null, 1);
        Thread thread = factory.newThread(new Runnable() {

            public void run() { return; }

        });
        assertNotNull(thread);
        assertTrue( thread.isDaemon() );
    }

    @Test
    public void newThreadsShouldNotYetBeStarted() {
        WorkerThreadFactory factory = new WorkerThreadFactory("", 1);
        Thread thread = factory.newThread(new Runnable() {

            public void run() { return; }

        });
        assertNotNull(thread);
        assertFalse( thread.isAlive() );
    }

    @Test
    public void newThreadsShouldHaveGivenPrefixInName() {
        WorkerThreadFactory factory = new WorkerThreadFactory("prefix", 1);
        Thread thread = factory.newThread(new Runnable() {

            public void run() { return; }

        });
        assertNotNull( thread.getName() );
        assertTrue( thread.getName().startsWith("prefix") );
        assertTrue( thread.getName().startsWith("prefix-") );
    }

}
