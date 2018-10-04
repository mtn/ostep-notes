# Persistence

> We want to have information on our systems persist, even when the computer
> gets powered off or crashes.

# IO

Systems that don't take input aren't usually very interesting (since they
produce the same output always), nor are programs that produce no output
(because there'd be no point to running them). This motivates IO.

### System Architecture

The CPU is connected to system components via a series of _buses_, with ones
(physically) closer to the CPU being faster. Main memory is connected via the
_memory busy_, high performance IO devices (like a graphics card) via the _IO
bus_, and lower performance peripherals (like disks) via the _peripheral bus_.
On modern systems there are quite a few interfaces to the CPU, tailored to the
performance requirements of different hardware.

### A Canonical Device

Devices have two components: the _interface_ they present to other components in
the system, and the _internal structure_ that enables this abstraction. For
example, a device interface could be three registers to view the current device
status, initiate commands, and pass data in and out. The flow of using such
a device to load in data would involve the OS polling till the device is ready,
loading the data, and setting a command register to let the device know.

### Using Interrupts

Polling is inefficient, though, so we replace them with interrupts. The OS would
instead issue the request, put the calling process to sleep, and the device will
raise a _hardware interrupt_ when it's done executing, triggering an _interrupt
handler_.

In general, this approach is quite a bit better. However, for fast devices where
the request would be satisfied by the first time polling, it can actually be
slower. To combat this, a _two-phased_ approach which first polls and then
switches to interrupts can be used. One other performance optimization is
_coalescing_, where interrupts aren't immediately delivered to the CPU in the
hopes that more interrupts will come in, allowing multiple to be handled at
a time.

Another downside is the possibility of live-lock: we don't want the OS to
constantly be stuck serving interrupt handlers rather than actually running
user-level processes.

### More Efficient Data Movement With DMA

Another source of inefficiency in the canonical model is that the OS spends
a lot of time copying data into the memory of the device. A solution is _direct
memory access (DMA)_. The CPU just needs to tell the DMA engine what data to
copy and it'll do it, raising an interrupt when it's done, thus leaving the CPU
free to run something else.

### Methods of Device Interaction

There are two primary ways the OS communicates with devices. The first is
explicit IO instructions, where the user specifies a register to send or receive
data from, and a _port_ which names a device. Another approach is to use
_memory-mapped IO_, where device registers can be written to as if they are
normal memory locations. Neither option is really better.

### Device Drivers

Another problem the OS could face is that it needs to communicate with many
different devices, like different types of disks. Ideally, we want uniform
protocol for doing so, so specific code doesn't have to be written for each
device. This motivates an abstraction called the _device driver_, which allows
the OS to issue uniform read/write calls which are then passed through to
devices in a neutral way.
