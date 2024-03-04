OSU HiBD-Benchmarks (OHB) for HBase
=======================================

The OSU HiBD-Benchmarks project aims at developing benchmarks for evaluating Big Data middleware. 
The current version (0.9.2) of OHB contains micro-benchmarks for HBase.

---------------------------------------------------------------------
HBase Latency Micro-benchmarks
---------------------------------------------------------------------

The current version (0.9.2) of OHB presents micro-benchmarks to measure the
latency of a HBase Get or Put operation for different data sizes with one
client

HBaseSingleClientPut
----------------------------
The HBaseSingleClientPut micro-benchmark can be run in two modes:

 1. Auto-flush enabled - Does a put to the server for every operation
 2. Auto-flush disabled - Does a buffered put to the server

In both the modes, the HBase Put operations are repeated for a fixed 
number of iterations for data sizes 1B to 1M. The average latency per iteration 
is reported without considering the overheads due to start-up.

HBaseSingleClientGet
----------------------------
The HBaseSingleClientGet micro-benchmark performs Get operations for a fixed 
number of iterations for data sizes 1B to 1M. The average latency per iteration 
is reported without considering the overheads due to start-up.

---------------------------
Setting up and building OHB
---------------------------

Following are the steps for building OHB Micro-benchmark for HBase:

1. Set HBASE_HOME
   # export HBASE_HOME=<HBASE_HOME_DIR>

2. Change directory to hbase directory under
   OHB Micro-benchmark install directory
   # cd <OHB_INSTALL_PATH>/hbase

3. Run make to build the OHB Micro-benchmark for HBase
   (HBaseSingleClientGet, HBaseSingleClientPut)
   # mvn package

   The benchmark jar is available in <OHB_INSTALL_PATH>/hbase/target 

----------------------------
Running OHB Micro-benchmarks
----------------------------

Running HBase Cluster:

1. Start the HBase cluster

Running OHB:

1. Run OHB Put Latency Micro-benchmark

   # java -Djava.ext.dirs=<HBASE_HOME_DIR>/lib -Djava.library.path=<HBASE_HOME_DIR>/lib/native/Linux-amd64-64/ -cp <HBASE_HOME_DIR>/conf:<HBASE_HOME_DIR>/lib:<OHB_INSTALL_PATH>/hbase/target/ohb-hbase-0.9.2.jar edu.osu.hibd.ohb.hbase.HBaseSingleClientPut --auto-flush <true|false> 2> stderr.log

2. Run OHB Get Latency Micro-benchmark

   # java -Djava.ext.dirs=<HBASE_HOME_DIR>/lib -Djava.library.path=<HBASE_HOME_DIR>/lib/native/Linux-amd64-64/ -cp <HBASE_HOME_DIR>/conf:<HBASE_HOME_DIR>/lib:<OHB_INSTALL_PATH>/hbase/target/ohb-hbase-0.9.2.jar edu.osu.hibd.ohb.hbase.HBaseSingleClientGet 2> stderr.log
