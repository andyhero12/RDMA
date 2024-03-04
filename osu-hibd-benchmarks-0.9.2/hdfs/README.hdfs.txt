OSU Hadoop Benchmarks (OHB) for HDFS
=====================================

Requirements
============

- Java 1.7

- Hadoop 1.x, 2.x

Build
=====
Set JAVA_HOME and HADOOP_HOME. Then type 'mvn package' in the benchmark directory <ohb_home>.

Execute
=======
In the benchmark directory, there is a script 'run_ohb.sh'. This script takes
one parameter which is the name of the benchmark (SWL, SRL, SWT, SRT, RRL). To
run a particular benchmark, type:

<ohb_home>/run_ohb.sh <benchmark name>

This will execute the selected benchmark with the default parameter settings.
To change the parameters, modify the script. For details about parameter
settings, please follow the userguide in http://hibd.cse.ohio-state.edu/userguide/.
