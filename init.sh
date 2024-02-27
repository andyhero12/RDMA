#!/bin/bash
bin/hdfs namenode -format
sbin/start-dfs.sh
sbin/start-yarn.sh

