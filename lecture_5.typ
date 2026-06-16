#set document(
  title: [Lecture 5 - HPC Programming Models],
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
  2026-06-09
]

#let colourmaths(x, color) = text(fill: color)[$#x$]

#figure()[Notice: If you find any mistakes, please open an issue in #link("https://github.com/robomarvin1501/notes_rdma")[the github repository]]

= Recap and Introduction
We have discussed RDMA, its benefits and drawbacks, and we should now be able to write software that makes use of RDMA.
We are now going to jump to a very basic overview of High Performance Computing. Very basic since we are effectively
compressing a complete course into a single lecture. Once we have this background, we will reconnect this to RDMA,
through collective communication.

= High Performance Computing
There are 3 important things in HPC:
+ Performance
+ Performance
+ Performance

Cloud computing also has requirements of security, where we want good isolation between our processes. However, in HPC,
we will give up security for more performance. This is possible since we have more control over our computer clusters. \
Performance is a quantifiable measure of rate of doing computational work. We have multiple such measures. We may
measure at the level of the basic operations:
- ops - operations per second
- ips - instructions per second
- flops - floating point operations per second
We may also measure the rate at which a benchmark program is executed. This is generally a carefully crafted, and
controlled piece of code used to compare systems.
- Linpack Rmax
- gups (billion updates per second)
I will note that there is a drawback to benchmarks, that sometimes vendors use the benchmark as a target, rather than
real world performance, since they do not always directly correlate. Remember, in the competitive world, as soon as you
have some sort of measure, it quickly becomes a target.

There are 2 main perspectives on performance:
- Peak performance, which is the maximum theoretical performance possible for a system
- Sustained performance, which is observed for a particular workload and run, and may vary across workloads and possibly
  even between runs
We will note that the performance stated by a vendor, such as Intel, and Nvidia, is a theoretical number. Buying a
device does not guarantee that performance. Buying 1000 processors from Intel, and running a massively parallelised
program across them does not guarantee 1000 times the performance, but likely rather less (though possibly more).

== Two (Plus 1) Major Categories of Applications
Traditionally, HPC was mainly focused on Scientific Computing, such as in Physics and Chemistry. They mainly
make use of MPI, as it is the dominant programming model.

Another use is Big data, enterprise, and commercial computing. This focuses on large amounts of data, and data
analysis. Some software called Spark emerged for in memory computing. \
Big data mostly disappeared into AI, since AI requires huge amounts of training data, and also when running these
models, we need to store their weights. The main difference is that AI also requires huge amounts of compute, not just
data. This mainly uses Message Passing Programming Model (not the MPI standard!), and is moving towards PGAS (which is
for one sided communication).

=== Applications (Scientific & Engineering)
There are practically endless applications here. Between analysis of parts for aircraft, all the way to simulating the
covid19 virus back in 2020, and managing to create a vaccine in 2 years, rather than 20. The main problem with this is
that it is a very expensive method. To perform sufficiently accurate calculations, we need practically unlimited
computation, energy, space, and so on. However, we cannot deny the benefits that it brings us (as opposed to AI, where
we definitely can).

== Parallel Programming Models
We have no real way of continuing to massively increase the processing power of a single core, so the only real solution
to this is massive parallelisation. Programming models provide abstract machine models:
- Shared memory, many threads on the OS share memory, and may access this memory to share information. This is often
  does through things like pthreads, though there is also OpenMP, which provides a slightly more comfortable abstraction
  on top of pthreads. This is mainly used by scientists, and engineers, that do not want/need to understand the actual
  software like pthreads.
- The distributed memory model, and MPI (Message Passing Interface). It is very difficult if we have many different
  processors to have shared memory between them, since the communication speed between the different groups of memory is
  so limited. Additionally, it helps solve the failure mode problem, where in shared memory, if one core has power
  problems, the entire system fails, but in distributed computing, if one computer fails, then the system may continue
- Message Passing is relatively difficult. To resolve this, we created distributed systems, with logical shared memory.
  This memory assigns logical areas to each computer in the distributed system, and then create an abstraction layer
  that lets this appear and act like shared memory. This hides from the user the complications of passing information
  between the processors. This is called the Partitioned Global Address Space (PGAS).

#figure(
  caption: "",
)[
  #table(
    columns: (auto, auto, auto, auto, auto),
    align: horizon,
    table.header([Model], [Scalability], [Performance], [Ease of Use], [Portability]),
    "Shared Memory", "Limited", "High (local)", "Easy", "Moderate",
    "Message Passing", "High", "High", "Moderate", "High",
    "PGAS", "High", "High", "Hard", "Variable",
    "Hybrid", "Very High", "Best case", "Complex", "High",
  )
]
We will note that most programs make use of Message Passing, since it allows excellent performance, and an easy to use
abstraction, with only a limited increase in difficulty. It also allows us to optimise it to all manner of different
systems, without our physicist having to learn all the difficult things like RDMA, and rewrite his entire application
every time we create a new method of this computation. We simply change the backend of the MPI library, and he promptly
has all these benefits.

== MPI
=== What is MPI
MPI is a standardised, adnd portable message passing system designed to function on a wide variety of parallel computing
architectures. It enables processes to communicate with one another by sending and receiving messages, making it
suitable for distributed memory systems. It comes with a few key features:
- Portability: Runs on various parallel computing platforms
- Performance: Designed for high efficiency and Scalability
- Language support: Provides direct bindings for C, C++, and Fortran, but functionally has bindings for every language
  you may want
MPI has a few basic concepts:
- Processes: Independent execution units with separate memory spaces
- Communicators: Defines groups of processes that may communicate
- Ranks: Unique identifiers for processes within a communicator

=== MPI Communication Paradigms
+ Point to Point communication
  - This has blocking operations such as MPI_Send, MPI_Recv
  - Non blocking operations such as MPI_Isend, MPI_Irecv
  - These are used for direct communication between pairs for processes
+ Collective Communication
  - Operations involving a group of processes
  - Examples:
    - Broadcast: MPI_Bcast. We can obviously have this just be one process sending all the data to all the other
      processes, or we can do this in $O(log n)$ instead of $O(n)$, and have each process send to 2 children instead
      (there are other methods to optimise, like k-nary trees rather than binary, and more)
    - Gather/Scatter: MPI_Gather, MPI_Scatter
    - Reduction: MPI_Reduce, MPI_Allreduce. These are incredibly interesting, and we will focus on them. Reduce just
      means that each part computes part of the problem (like everyone finds their local minimum in an optimisation
      problem), and then at the end we find the result from each part (the minimum of the minima). In MPI_Reduce, the
      result is just kept at the root, and in Allreduce it is shared to all the nodes.
+ One-Sided Communication (introduced in MPI-2)
  - Allows a process to specify all communication parameters for both sending and receiving data
  - Examples include MPI_Put, and MPI_Get

Data parallelisation is a use of reduce. We may parallelise the computation of backpropagation (for example). We make
$n$ copies of our neural network, each copy is given an $n$-th of the data, and then backpropagates across that data. To
find the final weights, we just need to sum these results. This is a problem with many excellent solutions.

```c
#include <mpi.h>
#include <stdio.h>

int
main (int argc, char **argv)
{
    // Initialize the MPI environment
    MPI_Init ();

    // Get the number of processes
    int world_size;
    MPI_Comm_size (MPI_COMM_WORLD, &world_size);

    // Get the rank of the process
    int world_rank;
    MPI_Comm_rank (MPI_COMM_WORLD, &world_rank);

    // Get the name of the processor
    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    MPI_Get_processor_name (processor_name, &name_len);

    // Print off a hello world message
    printf ("Hello world from processor rank %d out of %d processors\n",
            world_rank, world_size);

    // Finalize the MPI environment.
    MPI_Finalize ();
}


Output:
Hello from processor rank 0 out of 4 processors
Hello from processor rank 1 out of 4 processors
Hello from processor rank 2 out of 4 processors
Hello from processor rank 3 out of 4 processors
```


== PGAS
=== What is PGAS
PGAS is a parallel programming model that provides a global memory address space, logically partitioned among all
processes. Each process has affinity to a portion of the shared memory, enabling both local and remote memory access.

Key characteristics: Combines the ease of shared memory programming, with the performance of message passing. It also
supports one sided communication, allowing a process to read / write memory without getting the other process involved.

Some common libraries include UPC, CAF, Chapel, C10, OpenSHMEM.

= Part 2: Message Passing Interface (MPI)
A slight problem here is that we have the MPI model, and the MPI library. The MPI library is the implementation of the
MPI model, and very standardised, but it is important to remember that they are distinct things, and not necessarily a
one to one correlation.

MPI point to point communication is for direct communication between two processes, and may be blocking or non blocking.
There is also collective communication, which involves all processes in a communicator. It is possible that the
communicator only has 2 processes, but also possible that it has 2 million.

We also have *one sided communication* (RMA). Here, a process directly accesses the memory of another, without its
active participation. There are a few key functions:
- MPI_Put: Write to remote memory
- MPI_Get: Read from remote memory
- MPI_Accumulate: Remote atomic update
There are a few additional memory model concepts:
- Exposure epoch (MPI_Win_post/start)
- Access epoch (MPI_Win_lock/unlock)
We will note that this is not massively used, since the person that did this did not really understand what he was
doing. Those that want one sided communication use PGAS instead.

== Key Terminology
- Rank: This is the unique identifier for each process within a communicator. It has the value in $[0, n - 1]$, where
  $n$ is the number of processes
- Communicator: A group of processes that may communicate with each other. Default is MPI_COMM_WORLD, which includes all
  processes. Custom communicators may be defined for subgroup operations
- Tag: This is an integer label attached to a message, and helps distinguish between different message types or
  sources. It is useful for filtering in MPI_Recv. Consider if we have a single channel, we may use tag to multiplex on
  this channel, and allow us to send many different sets of communication over this single channel.
- Message: A unit of communication, consists of a data buffer, data type, count, source, destination, tag, and
  communicator.
- Datatype: Describes the type of elements in a message (MPI_INT, MPI_FLOAT). May also define custom datatypes using
  MPI_Type_create_struct.
  Why does the type matter to MPI? Operations like Allreduce may be able to optimise depending on the type.

#pagebreak()
In these examples, each table is a table of processors, and data. The processors are the rows, and the data the columns.
#figure(
  caption: "Broadcast",
  grid(
    columns: 3,
    gutter: 2mm,
    align: center + horizon,
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
      )
    ],
    [Broadcast $==>$],
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, "", "", "", "", "",
        $A_0$, "", "", "", "", "",
        $A_0$, "", "", "", "", "",
        $A_0$, "", "", "", "", "",
        $A_0$, "", "", "", "", "",
        $A_0$, "", "", "", "", "",
      )
    ],
  ),
)
As we can see, broadcast simply transmits 1 data vector from 1 process, to all the other processes.

#figure(
  caption: "Scatter, and gather",
  grid(
    columns: 3,
    gutter: 2mm,
    align: center + horizon,
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, $A_1$, $A_2$, $A_3$, $A_4$, $A_5$,
        "", "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
        "", "", "", "", "", "",
      )
    ],
    [Scatter $==>$ \
      $<==$ Gather],
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, "", "", "", "", "",
        $A_1$, "", "", "", "", "",
        $A_2$, "", "", "", "", "",
        $A_3$, "", "", "", "", "",
        $A_4$, "", "", "", "", "",
        $A_5$, "", "", "", "", "",
      )
    ],
  ),
)
Scatter splits the vector, and sends the first value to the first processor, the second to the second processor, and so
on. Gather is in the other direction, where we gather together all the data from all the processes into a single process.
#figure(
  caption: "Allgather",
  grid(
    columns: 3,
    gutter: 2mm,
    align: center + horizon,
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, "", "", "", "", "",
        $B_0$, "", "", "", "", "",
        $C_0$, "", "", "", "", "",
        $D_0$, "", "", "", "", "",
        $E_0$, "", "", "", "", "",
        $F_0$, "", "", "", "", "",
      )
    ],
    [Allgather $==>$],
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
      )
    ],
  ),
)
Here, every process has a part of a vector, and we want to gather it, and ensure that the result arrives to everyone.

#figure(
  caption: "Alltoall",
  grid(
    columns: 3,
    gutter: 2mm,
    align: center + horizon,
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, $A_1$, $A_2$, $A_3$, $A_4$, $A_5$,
        $B_0$, $B_1$, $B_2$, $B_3$, $B_4$, $B_5$,
        $C_0$, $C_1$, $C_2$, $C_3$, $C_4$, $C_5$,
        $D_0$, $D_1$, $D_2$, $D_3$, $D_4$, $D_5$,
        $E_0$, $E_1$, $E_2$, $E_3$, $E_4$, $E_5$,
        $F_0$, $F_1$, $F_2$, $F_3$, $F_4$, $F_5$,
      )
    ],
    [Alltoall $==>$],
    [
      #table(
        columns: (2em, 2em, 2em, 2em, 2em, 2em),
        align: horizon,
        $A_0$, $B_0$, $C_0$, $D_0$, $E_0$, $F_0$,
        $A_1$, $B_1$, $C_1$, $D_1$, $E_1$, $F_1$,
        $A_2$, $B_2$, $C_2$, $D_2$, $E_2$, $F_2$,
        $A_3$, $B_3$, $C_3$, $D_3$, $E_3$, $F_3$,
        $A_4$, $B_4$, $C_4$, $D_4$, $E_4$, $F_4$,
        $A_5$, $B_5$, $C_5$, $D_5$, $E_5$, $F_5$,
      )
    ],
  ),
)
Alltoall is that every process has a vector, and every process does a scatter of its vector, and gathers all the
vectors. As may be seen above, if we consider the matrix of processes and data, this is like doing a transposition of
the matrix.
It is a very intense operation, since every process is both sending the whole vector of data, _and_ receiving. If
you imagine each vector is 1GB, and you have 12000 process, then _each_ process is receiving a gigabyte from each other
process, and sending a gigabyte to each other process.

== Multiple Algorithms, One Collective
The same collective operation may be implemented using different algorithms. Each algorithm trades off latency,
bandwidth, message size, and scalability. MPI libraries choose implementations based on heuristics, benchmarks, or user
settings. Not every implementation is best for every setup, consider if we have a datacentre in Haifa, and one in Tel
Aviv. We split them up due to electricity limitations, and the connection speed between them is clearly much slower than the
connection speed inside the datacentre. There are algorithms to optimise communicating across this boundary, when we
need to share information in a broadcast, for example.

== Theoretical Cost Model
We will use a simple cost model to evaluate the algorithm cost:
$
  T(n, P) = alpha + beta dot n + gamma dot n
$
Where
- $alpha$ is the startup cost, represents the fixed latency overhead associated with initiating any communication
  operation
- $beta$ is the communication cost, and denotes the inverse bandwidth, representing the per byte transmission time
  through the network fabric
- $gamma$ is the computation cost, where if we need to perform some computation operation on the data, that must also be
  factored in
- $n$ is the vector size
- $P$ is the number of processes

We are missing here the *incast term*, which accounts for congestion when multiple flows converge simultaneously, and
the *memory access term*, which captures the overhead of accessing data in different memory hierarchies.

== MPI_Allreduce
The purpose of allreduce is to combine the reduction, and broadcast in one step. All processes contribute values and
receive the reduced result. This is widely used in AI/ML for gradient aggregation, and is also used in scientific
computing for aggregating statistics. Implementing this on top of RDMA, for our architecture, is going to be our final
project.

There are a many different algorithms for implementing allreduce. Each has its own drawbacks, and benefits, and for a slight
spoiler, we are going to implement ring.
- Ring algorithm: Bandwidth efficient, better for large messages
- Recursive doubling - good for short messages
- Rabenseifner's algorithm - hybrid of reduce scatter and allgather

=== Ring
To detail ring further, each process has an input vector of data, and we need at the end that each process will have the
sum of all the input vectors in its output vector. For 4 processors, we will begin by splitting our input vectors into 4.
Every process will take a quarter of the vector (each taking a different quarter), and send it to the next in line in a
ring. We may now sum together the relevant part of the vector, and send the results to the right once more, meaning what
we have now sent is the sum of 2 entries, not just one. We now repeat this until every processor now has a quarter of
the final summed vector (note that we only sent the data 3 times, not 4, thank you fence post). We copy this part to the
output buffer, and send to the right once more. We now do this until everyone has all the vector.

Note, this is effectively applying reduce-scatter, and then allgather. Do this division of operations when you write
your implementation.

This algorithm is the classic application, and until recently, was the only algorithm used in the AI world. We will
discuss shortly to what it was changed, and why, but first, let us discuss the complexity, and how we measure it. We
mentioned above the classic cost model, so in our context:
$
  (n - 1) dot [alpha + beta (v / n) + gamma]
$
Where $v$ is the size of the original vector, and $n$ is the number of processors. This is the initial part of doing the
computation, but we still need to scatter the data, so we need to add on $(n - 1) dot [alpha + beta (v / n)]$, giving us
a total of:
$
  (n - 1) dot [alpha + beta (v / n) + gamma] + (n - 1) dot [alpha + beta (v / n)] \
  = 2(n - 1) [1 + beta v / n] + (n - 1) gamma
$
This algorithm is bandwidth optimal, since each node may saturate the bandwidth with its neighbours, and it appears to
not be dependent on $n$. However, $alpha$ is in fact dependent on $n$, so for all this algorithm is bandwidth optimal,
its latency is less good. As we increase the number of nodes, the latency increases. This is why AI stopped using this
algorithm, because they started using 10s of thousands of nodes, and the latency of this was beginning to become
untenable.

=== Scalable Hierarchical Aggregation And Reduction Protocol (SHARP)
Let us suppose that we want to handle _lots_ of nodes. We will have many nodes connected to switches, and the switches
connected to more switches, sending information between the nodes. What if we add computational ability to the switch?
Suppose we have $n / 2$ nodes connected to two switches each, with those switches connected to one parent switch, then
once these switches receive the $n / 2$ vectors from these hosts, then the switches can do the computation themselves,
and then pass it on to the parent switch, which connects the two together to a single vector. This single vector may
then be sent down the tree to all the nodes, where everyone receives the entire vector at the same time, in $O(1)$
(ignoring the transmission time of the vector). \ 
So, we have $2 times$ better bandwidth than the optimal ring algorithm, and latency of $O(1)$. We have not broken
mathematics, simply we broke the rule that computation must be done by hosts. In this course, we will keep to the rules,
since our lab already exists, and we are not going to modify the switches.

This is a structure in both scale up, and scale out networks. Scale up networks are networks where we add more
capability locally, and scale out where we add more networks together. Think the difference between making a single
stronger computer, and connecting together many computers. Inside computers today, we generally do this by adding more
cores, over a high speed network. Intel have QPI for their high speed network. When it comes to GPUs, Nvidia use NVLINK,
which can now even be used on the rack level, rather than just the computer level. \
We want these connections to be as fast as possible, because a cache miss means pulling data over this connection, which
can be on the order of hundreds of clock cycles, which is a significant amount of money when doing these sorts of
computations.

=== Returning to AllReduce - Topology Detection
As above, we can do allreduce over a tree, where we reduce up the tree, and broadcast down the tree. We are mostly going
to skip this, since Gil would rather speak about AI than this. For now, we are going to speak about detecting
topologies, and how we map rings to the hardware.

Networks are fairly complex these days. We have already discussed scale up, and scale out. When we buy a server these
days, it tends to have many compute nodes, be they GPUs, CPUs, etc. The connection within this server is very fast, an
approximate rule of thumb is that it is $20 times$ faster to communicate with nodes within the server, than to
communicate with nodes outside the server. Let us consider a box, with 8 processing engines, very high speed
communication within, and each is connected via a network card to the outside, and may communicate with the other
internal GPUs _either_ from the local network, or over the external network (though this is not worthwhile). \
Let us now consider that we have 1000 of these boxes, and we want to do allreduce with these 8000 GPUs. We do not want
to simply use the low speed network to do this, and we may instead do 8 rings simultaneously. \
GPU 0 of each box will perform ring with each other, same for GPU 1, and so on, and we pretend that the internal network
is "free". So, we do these 8 rings simultaneously, and then when its done, each box does its own internal ring, and thus
the data reaches every compute node.

Nvidia has known for a long time how to make the worlds best GPUs. The reason why Nvidia bought Mellanox is because they
understood that compute power was not going to be the be all and all of supercomputer processing, but networking was
becoming the limiting factor, and Mellanox already knew a lot about the networking stack. 


= Parallelism
== Data Parallelism
We have a couple of ways of applying parallelism, data parallelism vs model parallelism. In data parallelism, the data
is too large to be computed in one place, so we create many replicas of our AI model, and compute over different parts
of data in parallel. Model parallelism is that the model is too large, and cannot fit inside a single node, so we split
it up across many nodes, and compute as a group. \ 
This is particularly significant at the moment, since we are low on memory in the world, particularly HBM, since we are
trying to build datacentres at such an unprecedented rate, that the rate at which we can make more memory has not kept
up, and the time taken to build a new fab is very significant, so we have not been able to increase our production
ability. This is also not helped by the fact that memory manufacturers are sceptical about AI, and have not even begun
building new fabs, since there is significant belief in this being a pop-able bubble, and if it pops, its not like they
can just scale back their memory production to meet demand, once they have increased their ability to produce memory.

When trying to train a model with gradient descent, we do the following loop:
```
do {
  Forward path (activations) - calculate error
  Backward path  - calculate gradients
  update network weights (aka optimiser)
} while error is above threshold / not decreasing anymore
```

We can apply data initial parallelism, where we split the training across the GPUs, and then need to ad a reduce
operation, where we take the average gradient from all the GPUs:
```
do {
  Forward path (activations) - calculate error
  Backward path  - calculate gradients
  (all) reduce gradients (calculate the average of gradients from different copies)
  update network weights (aka optimiser)
} while error is above threshold / not decreasing anymore
```

We will note that the operation of updating the network weights is a very expensive operation. All the GPUs have the
same weights vector, and do the same operation, to get the same solution. This is inefficient. Instead, what we can do
is have each GPU perform the optimisation on its part of the data, before we scatter and reduce the data, and then
gather the optimised results.
```
do {
  Forward path (activations) - calculate error
  Backward path  - calculate gradients
  reduce scatter gradients (calculate the average of gradients from different copies)
  update network weights (aka optimiser) on the availoable part of the gradient weights
  all gather weights calculated in each GPU
} while error is above threshold / not decreasing anymore
```
This reduced the number of optimisations by $times n$.

== Pipeline Parallelism
So, we have 3 operations per parameter, a forward pass, a backward pass, and then allreduce. Allreduce probably takes
longer than the backward pass, and we are unable to carry out the next forward pass until the previous one has
completed. Similarly, for the backward pass, we cannot begin until the previous allreduce has completed. This makes
pipelining these operations difficult.

Let us consider a large job, of dependent data, which is split into 4 parts, followed by a large collective operation,
such as allreduce. We may instead split each of these parts into 4, and execute the relevant jobs in parallel across our
GPUs, as described in the below diagram. 

#figure(caption: "Pipeline splitting")[
  #image("images/lecture_5_pipelining.png", width: 60%)
]
