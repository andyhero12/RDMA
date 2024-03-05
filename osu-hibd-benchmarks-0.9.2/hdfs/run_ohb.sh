#!/bin/sh

# Copyright (c) 2011-2016, The Ohio State University. All rights
# reserved.
#    
# This file is part of the OSU HiBD-Benchmarks software package developed by the
# team members of The Ohio State University's Network-Based Computing
# Laboratory (NBCL), headed by Professor Dhabaleswar K. (DK) Panda.
#  
# For detailed copyright and licensing information, please refer to the
# license file LICENSE.txt in the top level OHB directory.
# 

print_usage(){
	echo "Usage: $0 [SWL | SWT | SRL | SRT | RRL]"	
}

test_home=`which $0`
test_home=`dirname ${test_home}`
test_home=`cd "$test_home"; pwd`

if [ $# -le 1 ]
then

        if [ "x$JAVA_HOME" = "x" ]
        then
                java_home=`which java`
                if [ "x$java_home" = "x" ]
                then
                        echo "No Java found. Exiting.. " >&2
                        exit 1
                fi
                java_version=`$java_home -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q'`
                if [ $java_version -lt 16 ]
                then
                        echo "No appropriate java found. Version greater than 1.5 required. Exiting.. " >&2
                        exit 1
                fi
                if [[ $java_home = */bin/java ]]; then
                        java_home=`echo $java_home | sed 's/\/bin\/java//g'`
                fi
        else
                java_home=$JAVA_HOME
        fi

       	if [ "x$HADOOP_HOME" = "x" ]
       	then
               	hadoop_home=`which hadoop`
               	if [ "x$hadoop_home" == "x" ]
               	then
                       	echo "No hadoop home provided. Exiting.." >&2
                       	exit 1
               	fi
               	if [[ $hadoop_home == */bin/hadoop ]]; then
                       	hadoop_home=`echo $hadoop_home | sed 's/\/bin\/hadoop//g'`
               	fi
       		export HADOOP_HOME=$hadoop_home
       	else
               	hadoop_home=$HADOOP_HOME
       	fi

	ohb_selected=$1
	ohb_selected=$(echo "$ohb_selected" | tr '[:upper:]' '[:lower:]')
	if [ "$ohb_selected" = "swt" ]	
	then
		echo "Running SWT"
		
		dir="$test_home/output"
		if [ -d "$dir" ]; then
			rm -rf $dir
		fi
		mkdir $test_home/output
		proc=4
		xargs -L 1 -P $proc -I {} sh -c "ssh {} $java_home/bin/java -cp $hadoop_home/share/hadoop/common/hadoop-common-3.0.0.jar:$hadoop_home/share/hadoop/hdfs/hadoop-hdfs-3.0.0.jar:$hadoop_home/share/hadoop/common/lib/*:$hadoop_home/share/hadoop/hdfs/lib/*:$test_home/target/ohb-hdfs-0.9.2.jar -Dhadoop.conf.dir=$hadoop_home/etc/hadoop -Djava.library.path=$hadoop_home/lib/native edu.osu.hibd.ohb.hdfs.HDFSWriteThroughput -fileSize 10000 -bSize 134217728 -rep 3 -bufSize 1 -outDir $dir 2>{}.err" <hostfile
		

		numfile=`find $dir -type f|wc -l`
		while [ $numfile -lt $proc ]; do
		        numfile=`find $dir -type f|wc -l`
		done

		prefixtosearch=$dir"/write_thr_*"
		grep -r "Write throughput" $prefixtosearch | awk '{print $4}' >$dir/tmp1.log
		
		echo "Number of clients: "$proc
		echo "Total Throughput: "
		cat $dir/tmp1.log | awk '{{sum=sum+$0;}}END{print sum " MBps";}'
	elif [ "$ohb_selected" = "srl" ]
	then
		echo "Running SRL"
		$java_home/bin/java -cp ./target/ohb-hdfs-0.9.2.jar:$hadoop_home/share/hadoop/common/hadoop-common-3.0.0.jar:$hadoop_home/share/hadoop/hdfs/hadoop-hdfs-3.0.0.jar:$hadoop_home/share/hadoop/common/lib/*:$hadoop_home/share/hadoop/hdfs/lib/* -Dhadoop.conf.dir=$hadoop_home/etc/hadoop -Djava.library.path=$hadoop_home/lib/native edu.osu.hibd.ohb.hdfs.HDFSReadLatency -fileName "/user/a" -bufSize 1
	elif [ "$ohb_selected" = "srt" ]
	then
		echo "Running SRT"
		dir="$test_home/output"
		if [ -d "$dir" ]; then
                        rm -rf $dir
                fi
                mkdir $test_home/output
		proc=4
		xargs -L 1 -P $proc -I {} sh -c "ssh {} $java_home/bin/java -cp $hadoop_home/share/hadoop/common/hadoop-common-3.0.0.jar:$hadoop_home/share/hadoop/hdfs/hadoop-hdfs-3.0.0.jar:$hadoop_home/share/hadoop/common/lib/*:$hadoop_home/share/hadoop/hdfs/lib/*:$test_home/target/ohb-hdfs-0.9.2.jar -Dhadoop.conf.dir=$hadoop_home/etc/hadoop -Djava.library.path=$hadoop_home/lib/native edu.osu.hibd.ohb.hdfs.HDFSReadThroughput -fileSize 10000 -bufSize 1 -outDir $dir 2>{}.err" <hostfile

		numfile=`find $dir -type f|wc -l`
		while [ $numfile -lt $proc ]; do
        		numfile=`find $dir -type f|wc -l`
		done

		prefixtosearch=$dir"/read_thr_*"
		grep -r "Read throughput" $prefixtosearch | awk '{print $4}' >$dir/tmp1.log
		echo "Number of clients: "$proc
		echo "Total Throughput: "
		cat $dir/tmp1.log | awk '{{sum=sum+$0;}}END{print sum " MBps";}'

	elif [ "$ohb_selected" = "rrl" ]
	then
		echo "Running RRL"
		$java_home/bin/java -cp ./target/ohb-hdfs-0.9.2.jar:$hadoop_home/share/hadoop/common/hadoop-common-3.0.0.jar:$hadoop_home/share/hadoop/hdfs/hadoop-hdfs-3.0.0.jar:$hadoop_home/share/hadoop/common/lib/*:$hadoop_home/share/hadoop/hdfs/lib/* -Dhadoop.conf.dir=$hadoop_home/etc/hadoop -Djava.library.path=$hadoop_home/lib/native edu.osu.hibd.ohb.hdfs.HDFSRandomReadLatency -fileName a -fileSize 20000 -skipSize 10 -bufSize 1
	else	
		echo "Running SWL"
		$java_home/bin/java -cp ./target/ohb-hdfs-0.9.2.jar:$hadoop_home/share/hadoop/common/hadoop-common-3.0.0.jar:$hadoop_home/share/hadoop/hdfs/hadoop-hdfs-3.0.0.jar:$hadoop_home/share/hadoop/common/lib/*:$hadoop_home/share/hadoop/hdfs/lib/* -Dhadoop.conf.dir=$hadoop_home/etc/hadoop -Djava.library.path=$hadoop_home/lib/native edu.osu.hibd.ohb.hdfs.HDFSWriteLatency -fileName a -fileSize 20000 -bSize 134217728 -rep 3 -bufSize 1
	fi
else
	echo "Wrong usage of script"
	print_usage
fi
