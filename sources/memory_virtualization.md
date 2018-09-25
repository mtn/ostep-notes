# Memory Virtualization

> Like CPU resources, operating systems provide certain illusions to programs in terms of memory. For example, providing each process the illusion that it has a large personal address space.

## Address Spaces

### Early Systems

Early systems didn't provide much abstraction. There would just be one running process, and it'd get access to all available memory (besides what was being used by the OS).

### Multiprogramming and Time Sharing

Running multiple processes at the same time, or _multiprogramming_ complicated things but also allowed for better _utilization_. A naive implementation would be to run a process for awhile, giving it full access to resources, and then save its full state to disk and then switch to another. This is slow, however. A better solution is keeping processes in memory while switching between them. With this sort of solution, _protection_ of each processes' memory from each other becomes important.

### The Address Space

The _address space_ is the basic abstraction of physical memory, the running programs view of the system memory. It contains the program's _code_, a _stack_ which tracks location in the function call chain and store local variables, and the _heap_ to store dynamically-allocated managed memory. Because the stack and the heap both grow, they are placed at opposite ends of the address space and consume space towards each other (though this is complicated when we introduce threads).

Each program is under the illusion that it's been loaded at the beginning of the address space (at address 0), but obviously this can't be the case. Rather, this seems true because the OS _virtualizes memory_, mapping virtual addressed the process is aware of to true physical addresses.

### Goals

- _Transparency_: the fact that the OS is virtualizing memory should be invisible to the running process
- _Efficiency_: the virtualization shouldn't introduce much overhead
- _Protection_: processes should be protected from one another, and the OS itself from the processes

## Interlude: Unix Memory API
> A fair bit is omitted about `malloc`, `free`, etc.

_Stack_ memory is managed implicitly by the compiler. For example, a local variable being initialize involves an implicit allocation on the stack by the compiler. _Heap_ allocations are used when long-lived memory is required, and are handled explicitly by the programmer.

## Mechanism: Address Translation

Memory virtualization pursues a similar strategy to CPU virtualization, using hardware support. The general approach is _hardware-based address translation_, where hardware transforms each _virtual_ address into a _physical_ one. Alongside this mechanism, the OS helps set up hardware and manages memory. The goal is to create a illusion that each program has its own private memory.

We begin with several simplifying assumptions:

- The address space must be placed contiguously in physical memory
- The size of the address space is smaller than physical memory
- Each address space is the same size

From the point of view of a running process, the address space starts at address 0 and grows to at most 16 KB. For practical reasons, we want to have this process be actually be running somewhere else, and then transparently (to the process) relocate the process.

### Dynamic (Hardware-based) Relocation
> aka base and bounds

Each CPU has two registers, `base` and `bounds` that indicate the start and end of the address space. While the program runs each address is increased by the value of the base register.  To provide protection, the _memory management unit (MMU)_ checks that a memory access is within bounds of the process. "Dynamic" from the name refers to the fact that address relocation can happen dynamically at runtime (by changing `base` or `bounds`).

### Hardware Support: A Summary

Thus far, we've introduced to

- _Privileged and user modes_, where the CPU provides a limited permission scope to user programs
- _Base and bounds registers_, which are a simple mechanism for address translation
- _Exceptions_, which allow the CPU to preempt a user program and run an _exception handler_ when it executes an illegal instruction (like trying to access illegal memory)

### Operating System Issues
> things the OS has to do

- When a new process is created, the OS needs to find memory for its address space. Under our simplifying assumptions (all address spaces are the same size, etc.), this is easy, but in realistic systems it involves some sort of _free list_.

- When a process is terminated, it needs to reclaim its memory.

- State must be managed during context switches. Since there is only one _base_ and _bounds_ register each, they must be saved and restored into something like a _process control block_ for address translation to work correctly.

- The OS must provide _exception handlers_, prepared at boot time, so it knows what to do when exceptions occur.

## Segmentation

Base and bounds is a fairly simple implementation that meets some of the important goals of memory virtualization (transparency, efficiency, protection). However, there are also downsides. In particular, there can be substantial _internal fragmentation_, when lots of space between the stack and heap isn't used. On a 32 bit system, each program would have an address space of nearly 4 GB, but would typically use only a few MB. This motivates a generalization called _segmentation_.

### Segmentation: Generalized Base/Bounds

Because _code_, _stack_, and _heap_ are logically separate segments, by placing each separately into different parts of physical memory we can only allocate space to used memory. To support this, we have three pairs of _base_-_bounds_ pairs -- one for each segment. We can tell which segment an address belongs to explicitly by checking bits in the address (ex. the top two bits, and the rest storing the offset) or implicitly based on usage. Also, since the stack grows in a different direction from the heap, we require an additional hardware register tracking which direction a segment grows.

### Support for Sharing

In the interest of efficiency, the OS can also support memory sharing. For example, the OS might be able to save memory by having several processes read from the same memory. Additional _protection bits_ are used to implement this, indicating the read/write permissions a program has for each segment. When a user program violates the permissions specified by the protection bits, hardware raises an exception.

### Fine-grained vs. Coarse-grained Segmentation

Just as segmentation split up segments more finely than base-bounds pairs, various operating systems like Multics have attempted even more fine-grained segmentation. To manage this, they would maintain some sort of _segment table_. The goal was that the OS could use the additional information to better organize memory.

### OS Support

Segmentation pretty effectively solves the internal fragmentation problem of base-bounds, but introduces new ones. As processes start, memory becomes full of little holes, making it progressively harder to allocate new segments (known as _external fragmentation_). A naive approach is to periodically stop and relocate all processes, compacting memory. This is expensive though, so practical algorithms like _best-fit_ and the _buddy algorithm_ try to manage free space as well as possible. It's difficult to come up with a good general solution though.
