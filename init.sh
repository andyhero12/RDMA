#!/bin/bash
mkdir dummy
mkdir dummyRAM
bin/hdfs namenode -format
sbin/start-dfs.sh
sbin/start-yarn.sh

