# Concurrency

> We want a solution that's _more correct_ than letting everyone grab out
> a peach at once, but _more efficient_ than having them all line up.

## An Introduction

Building on top of previous abstractions, which provided the illusion of
multiple _virtual CPUs_ and a large and private _virtual memory_, we can have an
abstraction for points of execution. Classical programs have just one point of
execution, but we could plausibly have multiple. The result _threads_, looks
like multiple processes, except that they all share the same address space.

Each thread has a program counter and a private set of registers (so switching
threads involves a _context switch_, though we don't have to switch page
tables). Each thread has its own stack (so multiple function executions can
happen in the address space at once), sometimes called _thead-local storage_.

### Why Use Threads?

- _Parallelism_: it's possible to more effectively use multi-core CPUs
- _Avoiding blocking_: overlap of IO/blocking activities and other activities
  becomes possible within one program

### The Basic API

On Unix, threads can be created with `pthread_create`, and `pthread_join` makes
the calling thread wait for another thread to terminate before it proceeds. The
order that threads are run is otherwise non-deterministic, governed by some
scheduling algorithm. This can lead to _data races_, where uncontrolled
scheduling can produce non-deterministic results when code is run. This
basically happens because operations are often not atomic meaning the program
can be pre-empted in the middle of their execution, causing the end result to
come out different from what's expected.

### Mutual Exclusion

To solve this, we need _mutual exclusion_, to ensure that only one point of
execution passes through certain _critical sections_ at a time. One approach
would be to have more sophisticated instructions, like `memory-add` that are
processed atomically, but this breaks down first because we would have to have
tons of them, and second because we'd end up with the same problem composing
these operations. Instead, we build a set of _synchronization primatives_ in
hardware which allow us to section off critical sections in a way that's much
more flexible.

### Condition Variables

Another common situation is when we have one thread that needs to wait for
another to finish executing before moving forward. For example, we could have
a thread that initiates some IO, and we want it to sleep until the IO is
finished and be awoken then. This will involve _condition variables_.

## Interlude: Unix Threat API

- Threads are created with `pthread_create`
- A thread can wait for another to finish by calling `pthread_join`
- A lock can be initialized by calling `pthread_mutex_init`, locked with
  `pthread_mutex_lock`, and unlocked with `pthread_mutex_unlock`
- Condition variables can be implemented with `pthread_cond_wait` and
  `pthread_cond_signal`

Code using these primitives can be compiled with `pthread.h`.

## Locks

Locks allow _critical sections_ to behave as if they are just one atomic
instruction.

### Locks: The Basic Idea

The state of a lock is tracked by a _lock variable_, which is either _acquired_
or _available_ at a given time. Calls to `lock` try to acquire the lock (and
succeed if it's available), and calls to `unlock` render it free again. This
basic API gives the programmer some control over scheduling back. POSIX locks
are called _mutexes_. These locks are implemented using a combination of
hardware support and implementation in the OS.

### Evaluating Locks

- Locks should provide _mutual exclusion_ (basically, they need to work)
- Locks should be as _fair_ as possible, with no process getting _starved_
- Locks shouldn't introduce a significant performance overhead

### Some Lock Implementations

The simplest possible implementations is having calls to `lock` disable
interrupts and calls to `unlock` re-enable them. The guarantees that operations
within the lock run atomically, but require trusting the user program to call
a privileged instruction and not abuse it. This also doesn't work on
multiprocessors, since the code section could easily be run on other processors
that don't have interrupts disabled. The approach can also be inefficient, and
losing interrupts can cause negative effects. Thus, the approach is not really
used, except in limited cases within the OS.

#### Without Hardware Support

An attempt at a solution that doesn't require this trust could use a flag
variable which is set and unset when the lock is held and released. When the
variable is locked, a waiting process can just spin-wait, doing nothing and
burning cycles till it has a turn. The problem with this naive implementation is
a failure of mutual exclusion: multiple threads could get access to the flag at
a time.

#### Spin Locks

A simple hardware primitive, `test_and_set`, helps out. The instruction returns
the old value and updates it atomically, which is enough to implement
a _spin-lock_ in software (set the variable to acquire the lock, check the
return value to decide whether to proceed into the critical section). Spin locks
are correct, but not fair (they don't provide guarantees against starvation).
Performance will differ based on the number of available cores -- lots of
performance is sacrificed if lots of threads are contending for a lock on one
CPU core, since entire cycles would be spent spinning. But across multiple
cores, this cost is less because while one lock spins on one core, actual
progress through the critical section could be made on another.

#### Compare and Swap

A slightly more powerful instruction than `test_and_set` is `compare_and_swap`,
which checks if the value at an address equals some `expected`, and updates it
to some new value if so. It's straightforward to implement a spin-lock using
this primitive (set the flag if it's unset, otherwise don't set it), but it can
also be used to support _lock-free synchronization_ (described later).

#### Load-Linked and Store-Conditional

Another way we could acquire locks is by retrieving the value of the lock flag
in one step, but only updating it if it remains unchanged from the time it was
read from memory. This is the idea behind `load_linked` and `store_conditional`.

#### Fetch-And-Add

A final primitive is `fetch_and_add`, which atomically increments a value while
returning the old value. This can be used to implement a lock that guarantees
progress for all threads: each value has a turn for some value of a counter, and
whenever a thread wants access to a lock it increments the counter.

### Reducing Spinning

Each of the above approaches involves a lot of spinning, which we would ideally
want to reduce. A naive approach is to just have processes yield whenever they
try to acquire the lock and fail. This sort of works, but when we have a lot of
threads going we can still end up wasting a lot of CPU time checking if the lock
is available and finding it's not.

#### Using Queues: Sleeping Instead of Spinning

Rather than just relying on the scheduler to determine when processes check for
the locks, we could assert more control. One way to do this is to have the OS
maintain a queue of processes waiting on a lock, which are put to sleep when the
request fails, and have the OS wake them up when the lock becomes available.
This is just like yielding, except the process ends up asleep and doesn't burn
CPU cycles. These ideas are implemented in terms of `park` and `unpark` on
Solaris and as futexes on Linux.

## Lock-based Concurrent Data Structures

When thinking about how to allow concurrent access to data in data structures,
we want to add the locks such that operations are all _correct_, without
sacrificing too much _performance_.

### Concurrent Counter

A simple "data structure" is just a counter that gets incremented across several
threads. By acquiring a lock before modifying it and releasing it, we can
guarantee correctness. Even in this case, we can observe how poorly performance
scales (the goal is _perfect scaling_).

### Scalable Counting

A tradeoff to improve performance of counters are _approximate counters_. Each
CPU keeps its own counter (with a lock, so threads on that CPU can contend for
it), and periodically synchronizes with a global counter by acquiring the global
lock.

### More Complex Data Structures

In general, scaling for more complex data structures involves protecting
specific parts of the structure with locks, rather than having one global lock.

## Condition Variables

Besides locking data structures, we also want to be able to check _condition_
and then conditionally continue execution (ex. `join`).

### Definitions and Routines

When a thread wants to wait for something, it an put itself in a queue to be
awoken when a signal comes in for them (_condition variable_). On Unix, this is
done with `pthread_cond_wait` and `pthread_cond_signal`.

`wait` takes a lock, in order to avoid concurrency problems where the parent
incorrectly detects the status of the child, which matters if it decides to call
`join`. Since updating isn't an atomic operation, without a lock it could read
an incorrect status and stay asleep forever.

### Producers and Consumers

A common situation is having a buffer where some process (_producer_) is putting
stuff in, and another (_consumer_) is taking stuff out (for example, Unix
pipes). Since this happens concurrently, we need to use locks somehow. This
problem can be solved generally with two _condition variables_ indicating the
number of available and filled slots in the buffer (so we know the exact status
of the buffer and know which processes to signal when the buffer is completely
full or empty).

### Covering Conditions

One common problem (encountered in the producer-consumer example) is dealing
with uncertainty while sending and receiving signals. For example, when multiple
processes request memory that isn't yet available, they might all be put to
sleep, but when memory doesn't become available we don't want to accidentally
wake up one that requested more than was newly freed. A simple but inefficient
solution is to _broadcast_ signals to all processes, which then wake up and
check if the condition they wanted is true, and go to sleep if it isn't.
