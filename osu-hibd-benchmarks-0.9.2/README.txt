For the latest information about OSU HiBD-Benchmarks (OHB) developed as a part
of the High-Performance Big Data (HiBD) project, please visit our website at:

  http://hibd.cse.ohio-state.edu


Pre-requisities
----------------
Install apache maven version 3.3. or update the pom.xml in the OHB dir installed.
For HBase, HDFS and Spark, ensure java 1.7 or higher is installed
For Memcached, ensure that rdma-memcached-0.9.5 is installed 

More information on RDMA Hadoop, RDMA HBase, RDMA Spark and RDMA Memcached can be
found at http://hibd.cse.ohio-state.edu

Building all benchmarks
-----------------------
This mvn project facilitates to build all benchmarks under the OHB project. 

Change directory to OHB install directory (directorty obtained on unzipping OHB tarball)
# cd <OHB-INSTALL-DIR>

Build all benchmarks using maven
# mvn clean package

Individual benchmarks information
---------------------------------
More information on individual benchmarks can be found below:
1) For information about OHB HDFS benchmarks, please refer to hdfs/README.hdfs.txt.
2) For information about OHB Memcached benchmarks, please refer to memcached/README.memcached.txt.
3) For information about OHB HBase benchmarks, please refer to hbase/README.hbase.txt.
3) For information about OHB Spark benchmarks, please refer to spark/README.spark.txt.
