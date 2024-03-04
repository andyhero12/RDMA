OSU HiBD-Benchmarks (OHB) for Memcached
=======================================

The OSU HiBD-Benchmarks project aims at developing benchmarks for evaluating Big Data middleware. 
The current version (0.9.2) of OHB contains micro-benchmarks for Memcached.

---------------------------------------------------------------------
Memcached Latency Micro-benchmarks (ohb_memlat)
---------------------------------------------------------------------

The current version (0.9.2) of OHB presents micro-benchmarks to measure the
(1) Latency of a memcached operation for different data sizes (ohb_memlat)
(2) Hybrid memory mode micro-benchmark that enables simulating overhead of 
    Memcached misses during out-of-memory and the latency incurred due to 
    SSD accesses. 
(3) Non-blocking API latency benchmark that illustrates the performance of 
    different non-blocking set/get APIs and supporting progress APIs.

ohb_memlat
----------------------------
The ohb_memlat micro-benchmark can be run in three modes:

 1. GET - The OHB Get Micro-benchmark measures the average latency of memcached
          get operation.
 2. SET - The OHB Set Micro-benchmark measures the average latency of memcached
          set operation.
 3. MIX - The OHB Mix Micro-benchmark measures the average latency per operation 
	  with a get/set mix of 90:10.

In all three micro-benchmarks, the memcached operations are repeated for a fixed 
number of iterations for data sizes 1B to 512KB. The average latency per iteration 
is reported without considering the overheads due to start-up.

ohb_memhybrid
----------------------------
The ohb_memhybrid micro-benchmark enables accessing stored key/value pairs in two 
patterns: 

  1. UNIFORM - All keys are selected uniformly at random.
  2. NORMAL - Some keys are accessed more frequently than others.

For both these patterns, the number of key/value pairs stored can be controlled using 
configurable value size, maximum aggregated memory and spill factor. 

ohb_memlat_nb
----------------------------
The ohb_memlat_nb micro-benchmark measures average latency of the newly introduced 
non-blocking set and get operations, i.e., iset, iget, bset, bget, etc. It has two
modes: 

  1. ISET/BSET - <max-memory>/<value-size> key/value pairs are stored into Memcached 
                 servers using non-blocking set requests
  2. IGET/BGET - Key/value pairs are read using either at random or zipf pattern using
                 non-blocking get requests from pre-loaded Memcached servers. 

For both these modes, users can specify aggregated maximum server memory, value size, 
progress API of choice and the threshold on number of ongoing requests. 

---------------------------
Setting up and building OHB
---------------------------

OHB Micro-benchmark for Memcached needs to be compiled with Libmemcached library. 
Following are the steps for building OHB Micro-benchmark for Memcached:

1. Ensure that libmemcached.home property is set to the fully-qualified RDMA-Memcached-0.9.5 install 
   path in pom.xml
   # Add/update following in pom.xml
    <properties>
        <libmemcached.home>${RDMA_MEMCACHED_INSTALL_DIR}/libmemcached</libmemcached.home>
    </properties> 

2. Change directory to OHB Micro-benchmark install directory
   # cd <OHB_INSTALL_PATH>/memcached

3. Run mvn to build the OHB Micro-benchmark for Memcached 
   # mvn package

   All micro-benchmarks will be installed in <OHB_INSTALL_PATH>/memcached/target. Run ls to verify
   # ls <OHB_INSTALL_PATH>/memcached/target/ohb_mem*

----------------------------
Running OHB Micro-benchmarks
----------------------------

Running Memcached server:

1. Start the Memcached server
   # <MEMCACHED_INSTALL_PATH>/bin/memcached 

Running OHB:

1. Add libmemcached library path to LD_LIBRARY_PATH
   # export LD_LIBRARY_PATH=<LIBMEMCACHED_INSTALL_PATH>/lib:$LD_LIBRARY_PATH

2. Run OHB Memcached Latency Micro-benchmark
   # <OHB_INSTALL_PATH>/ohb_memlat --servers=<SERVER:PORT[,SERVER:PORT,..]> --benchmark=<GET|SET|MIX|ALL>

3. Run OHB Memcached Hybrid Micro-benchmark
   # <OHB_INSTALL_PATH>/ohb_memhybrid --servers=<SERVER:PORT[,SERVER:PORT,..]> —scanmode=<UNIFORM|NORMAL> --maxmemory=<agg.-memory-MB> --valsize=<size-in-bytes> --misspenalty=<penalty-in-ms> —spillfactor=<number-greater-than-one>

4. Run OHB Memcached Non-Blocking Latency Micro-benchmark
   # <OHB_INSTALL_PATH>/ohb_memlat_nb --servers=<SERVER:PORT[,SERVER:PORT,..]> —reqtype=<iset|iget|bset|bget> —-progresstype=<test|wait> --maxmemory=<agg.-memory-MB> --valsize=<size-in-bytes> —reqthresh=<num-requests>
