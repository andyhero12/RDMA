OSU HiBD-Benchmarks (OHB) for Spark
=======================================

The OSU HiBD-Benchmarks project aims at developing benchmarks for evaluating Big Data middleware. 
The current version (0.9.2) of OHB contains micro-benchmarks for Apache Spark.

Building
-----------------------
Run "mvn clean package"


Running tests
----------------------
Run similar to spark examples GroupByTest
Helper script ohb_run_example provided

MASTER=spark://<master-hostname>:7077 <OHB-INSTALL-DIR>/spark/ohb_run_example edu.osu.hibd.ohb.spark.[GroupByTest|SortByTest] <number-of-maps> <number-of-key-value-pairs> <value-size> <number-of-reducers>

Example:
cd <OHB-INSTALL-DIR>/spark/
MASTER=spark://storage01:7077 ./ohb_run_example edu.osu.hibd.ohb.spark.SortByTest 32 65536 4092 32 
