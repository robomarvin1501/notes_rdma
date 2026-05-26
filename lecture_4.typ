#set document(
  title: [Lecture 4],
  author: "Gidon Rosalki",
  date: auto,
)
#set heading(numbering: "1.")
#set text(font: "New Computer Modern")
#set page(margin: (
  bottom: 0.5cm,
  right: 1.5cm,
  left: 1.5cm,
  top: 1.5cm,
))
#set list(indent: 10pt)
#set enum(indent: 10pt)

#show title: set align(center)
#show link: set text(rgb("005eff"))
#show link: underline
#show math.equation.where(block: true): set block(breakable: true)
#title()
#align(center)[
  Gidon Rosalki \
  2026-05-26
]

#let colourmaths(x, color) = text(fill: color)[$#x$]

#figure()[Notice: If you find any mistakes, please open an issue in #link("https://github.com/robomarvin1501/notes_rdma")[the github repository]]

We discussed verbs last week, and things like queue pairs, scatter gather, and so on. Today we will discuss memory, and
once we have these building blocks, we are going to try and make RDMA practical, such as when, and how we use this, when
can one actually access memory. There will be two real world examples for this. Further on in the semester, we will move
on to things like AI, training and inference, and how RDMA has an impact on this. For example, we will discuss DeepSeek,
which is remarkable open about their training processes, where whenever they do something, they publish a paper on it.
Naturally, they also screw up, but the publicity of their work is nice.

= Reminder
== OS Memory Access
The CPU uses the Main Memory Unit in order to access the main memory (RAM). Other devices use the IOMMU. Memory is
kept in _pages_, usually of size 4KB. One cannot access less memory than that at once. Memory is swapped in and out of
RAM according to how much space there is in the RAM, and then information from the RAM is swapped in and out of the L
caches of the CPU for the CPU to access quickly. Direct Memory Access is a device to access the memory directly,
rather than requesting from the CPU. This access is over a "bus", such as PCI(e). The OS manages a virtual memory space
for the process, where the process thinks that it is the only process on the machine, such that it cannot try and infer
information about other processes, or change their memory. This makes the mapping to the swap happen transparently to
the program, since it just requests a page, and the OS handles returning it to the program. 

== Memory Registration
This is a mechanism that allows an application to describe a set of virtual or physical contiguous memory location to
the NIC as as virtually contiguous buffer using a Virtual Address.  This registration process pins the memory pages, to prevent the pages from being swapped out, and keep
the virtual to physical mapping. \
During the registration, the OS checks the permissions, and the registration writes to the NIC translation table from
virtual addresses to physical addresses. 

This results in a Memory Region (MR), where every MR has a remote, and a local key (r_key, l_key), which are used in the
WR. The same memory buffer can be registered several times, with different access permissions. Every registration
will result in different keys. 

This is an _expensive_ operation, as we discussed previously. As a result, one should minimise how frequently one calls
it. 

=== Region Registration
There is a flow to carry out this memory access // TODO diagrams, 9, 1016

When the consumer wants to send data, it registers the memory. The channel interface software then pins the memory with
the NIC, and returns the l_key, and r_key to the consumer. Once this is done, the consumer submits a WR to the NIC,
which then sends the access data to the remote. 

On the remote, it is a bit more complicated, so we will continue to pretend bits of it do not exist for a bit. The
remote agent has received the data buffer info 9(ba, length, r_key) to the remote agent, which then carries out an
RDMA operation, where it sends a WR to the NIC, which checks if it is legal, carries out the translation, and access the
memory.

#pagebreak()
// TODO example code 11, 1020
```c
int foo (struct ibv_ *pd, struct ibv_qp *qp)
{
  struct ibv_mr *mr;
  struct ibv_sge *sge;
  struct ibv_recv_wr wr, *bar_wr;
  int length = 16384;
}
```

The above code is the standard, and now given that, we need to somewhat discuss the protection domain. Let us assume
that we have some sort of server, say a university server, where not all users are allowed to access the entire machine
at once. Let us assume that Gil wants to give us all access to _read_ our grades, but naturally does not want to give us
write access. Naturally, Gil needs both read, _and_ write access. However, we now have a problem with this model of
returning a pointer, since once we have done memory registration, we only have a single access key, with a set of
permissions. We are doing something that is a security nightmare in memory registration, where we can directly access
memory. What we will do is something called a *protection domain*. So now, we have a buffer that is part of a protection
domain, and instead of people accessing the memory directly, they access the protection domain. Blocks of memory are
assigned to protection domains, and trying to access memory in a different protection domain is an error. 

On the one hand, this is relatively expensive, but it is excellent in terms of security to give everything its own
protection domain. So what we can now do is register the memory twice, once to domain A, once to domain B, where A has
read and write access, but B only has read access. So, as part of the API, whenever we register memory, we now also need
to register it to a protection domain. 

=== On Demand Paging
As we discussed, memory registration is expensive, and simply registering at the beginning is not necessarily a
solution, because we may dynamically need more memory. A solution is that the OS already has a disk paging solution,
where we bug the OS to return our pages to us from the disk. A similar solution may be provided to the NIC, which
requests pages that were swapped out by the OS. This operates almost identically to the CPU, but also requires that the
OS informs the NIC when pages are swapped out, so that they may be deleted from its translation table. 

This concept is called On Demand Paging, which does in fact work, but interestingly, is not used in the real world. This
is because we want predictable performance, we do not want to have to wait for the OS to swap pages back in, since this
can cause significant delays to the entire compute cluster. \
We instead assume that the users know what they are doing, and write software that handles the memory themselves. 

= IB Ops and Protocols
Recall the RDMA opcodes, such as send, Write, Read, Atomic, and so on. 

== The "Eager" Protocol
Let us assume that we want to send a message. We begin with asking how much data we want to send. Beginning with the
responder, we open a few 4K buffers, and post them as receive buffers. The requestser sends to a remote QP using the
send opcodce, which are typically signalled, so we reeive a work completion when done. 

This protocol has minimal startup obverheads, and is used to implemenmt low latency message passing for smaller
message. The down side is ```c memcpy```, since it is not zero copy. // TODO 20 1044

== The "Rendezvous" Protocol
Since eager only works for small messages, we needed something new. For those who were lucky enough to not learn French,
rendezvous simply means meeting, and is not pronounced how you think. // TODO 21 1045
 
We do thnis through reads and writes:
== RDMA_READ vs RDMA_WRITE
If we instead want to send a large amount of data, we have two main ways: 
+ WRITE: The sender opens with ```RNDZ_START```, receivbes a ```RNDZ_REPLY```, and then writes the data to the received
  buffer, and completes with a ```FIN```. 
+ READ // TODO

This is a common, and standard protocol for RDMA communication. We even build a high abstraction layer over it, called
MPI, which makes life easier for physicists, that should not be learning how to use RDMA verbs directly, but rather
should focus on their difficult physics questions. 

Which is better between read and write? Depends on the situation. Consider for read, we can send the data and have it
cost nanoseconds to the sender CPU, since it just informs the receiver, and then can wait for the receiver to read it,
while doing other tasks. \
For the sender, this is also very cheap, since the NIC is doing the reading, and the CPU continues to compute other
tasks while the NIC reads the data across the network. When receiving data, we need to use "progress" every so often,
such as ```c MPI_progress```, to check on the progress of the transfer, but we can choose when to do this, such as when
we are not doing expensive operations in memory, since this will cause us to lose the data in the cache. We can instead
do it when we are not in the middle of a matrix multiplication (for example), and not lose vital time in our operations.
