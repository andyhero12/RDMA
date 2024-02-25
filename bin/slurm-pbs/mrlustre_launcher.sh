#!/bin/bash

# Copyright (c) 2011-2016, The Ohio State University. All rights reserved.
#
# This file is part of the RDMA for Apache Hadoop software package
# developed by the team members of The Ohio State University's
# Network-Based Computing Laboratory (NBCL), headed by Professor
# Dhabaleswar K. (DK) Panda.
#
# For detailed copyright and licensing information, please refer to
# the license file LICENSE.txt in the top level directory. 


read_dom () {
        local IFS=\>
        read -d \< E C
}

test_home=$1
hadoop_home=$2
conf_dir=$4
mode_of_operation=$7
java_home=$8
resource_manager=$9

if [ $resource_manager -eq 1 ]
then
        job_id=$SLURM_JOBID
        hosts=`scontrol show hostnames $SLURM_NODELIST`
else
        job_id=$PBS_JOBID
        hosts=`cat $PBS_NODEFILE`
fi

hadoop_log_dir=$1"/log_"$job_id
start_hadoop=${10}

mkdir $hadoop_log_dir
if [ "x$6" != "xnull" ]
then
    lustre_path=$6"/hibd_data_"$job_id
    if [[ -d "$lustre_path" ]]
    then
        rm -rf $lustre_path
    fi

    mkdir $lustre_path
    lfs setstripe -s 256M $lustre_path
fi

if [ $3 -ne 1 ] 
then
        if [ $3 -eq 0 ]
        then
                user_conf_file=$5
        else
                touch $test_home/tmp_file
                user_conf_file=$test_home/tmp_file
        fi

    cp $hadoop_home/etc/hadoop/* $conf_dir/
    master=`hostname -s`

    serverlist=""
    rm -f $conf_dir/slaves
    for i in $hosts
        do
                if [ "$i" != "$master" ]
                then
                        echo $i >> $conf_dir/slaves;
                        serverlist+=$i,
                fi
        done


############___yarn-site.xml___########
cat << EOF > $conf_dir/yarn-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
        <property>
                <name>yarn.nodemanager.aux-services</name>
                <value>mapreduce_shuffle</value>
        </property>
        <property>
                <name>yarn.resourcemanager.scheduler.address</name>
                <value>$master:8030</value>
        </property>
         <property>
                <name>yarn.resourcemanager.address</name>
                <value>$master:8032</value>
        </property>
         <property>
                <name>yarn.resourcemanager.webapp.address</name>
                <value>$master:8088</value>
        </property>
         <property>
                <name>yarn.resourcemanager.resource-tracker.address</name>
                <value>$master:8031</value>
        </property>
         <property>
                <name>yarn.resourcemanager.admin.address</name>
                <value>$master:8033</value>
        </property>
EOF

$test_home/genConfFile.py $user_conf_file $conf_dir/yarn-site.xml "yarn.nodemanager.aux-services,yarn.resourcemanager.scheduler.address,yarn.resourcemanager.address,yarn.resourcemanager.webapp.address,yarn.resourcemanager.resource-tracker.address,yarn.resourcemanager.admin.address" Y Y

    if [ $mode_of_operation -eq 3 ]
    then
 
echo "export JAVA_HOME=$java_home"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_INSTALL=$hadoop_home"  >> $conf_dir/hadoop-env.sh
echo "export PATH=$hadoop_home/bin:$PATH"  >> $conf_dir/hadoop-env.sh
echo "export PATH=$hadoop_home/sbin:$PATH"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_MAPRED_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_COMMON_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_HDFS_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
echo "export YARN_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_COMMON_LIB_NATIVE_DIR=$hadoop_home/lib/native"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_CONF_DIR=$conf_dir"  >> $conf_dir/hadoop-env.sh
echo "export hadoop_log_dir=$hadoop_log_dir"  >> $conf_dir/hadoop-env.sh
echo "export YARN_LOG_DIR=$hadoop_log_dir"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_OPTS=-Djava.library.path=$hadoop_home/lib/native"  >> $conf_dir/hadoop-env.sh
echo "export LD_LIBRARY_PATH=$hadoop_home/lib/native"  >> $conf_dir/hadoop-env.sh

        if [ $3 -eq 0 ]
        then

##############___core-site.xml___################
cat << EOF > $conf_dir/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.default.name</name>
        <value>file://$lustre_path/namenode</value>
    </property>
    <property>
        <name>fs.local.block.size</name>
        <value>268435456</value>
    </property>
    <property>
    <name>hadoop.tmp.dir</name>
    <value>/tmp/hadoop_local_$job_id</value>
    </property>
EOF

$test_home/genConfFile.py $user_conf_file $conf_dir/core-site.xml "fs.default.name,fs.local.block.size,hadoop.tmp.dir" C Y

cat << EOF > $conf_dir/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.system.dir</name>
        <value>$lustre_path/mapred/system</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.staging.root.dir</name>
        <value>$lustre_path/mapred/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.staging-dir</name>
        <value>$lustre_path/yarn/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.command-opts</name>
        <value>-Xmx1024m -Dhadoop.conf.dir=$conf_dir</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>LD_LIBRARY_PATH=${hadoop_home}/lib/native</value>
    </property>
    <property>
        <name>test.build.data</name>
        <value>$lustre_path/benchmarks/TestDFSIO</value>
    </property>
EOF

$test_home/genConfFile.py $user_conf_file $conf_dir/mapred-site.xml "mapreduce.framework.name,mapreduce.jobtracker.system.dir,mapreduce.jobtracker.staging.root.dir,yarn.app.mapreduce.am.staging-dir,yarn.app.mapreduce.am.command-opts,yarn.app.mapreduce.am.env,test.build.data" M Y


        else

##############___core-site.xml___################
cat << EOF > $conf_dir/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.default.name</name>
        <value>file://$lustre_path/namenode</value>
    </property>
    <property>
        <name>fs.local.block.size</name>
        <value>268435456</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/tmp/hadoop_local_$job_id</value>
    </property>
    <property>
    <name>hadoop.ib.enabled</name>
    <value>true</value>
    </property>
    <property>
    <name>hadoop.roce.enabled</name>
    <value>false</value>
    </property>
</configuration>
EOF


cat << EOF > $conf_dir/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.system.dir</name>
        <value>$lustre_path/mapred/system</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.staging.root.dir</name>
        <value>$lustre_path/mapred/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.staging-dir</name>
        <value>$lustre_path/yarn/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.command-opts</name>
        <value>-Xmx1024m -Dhadoop.conf.dir=$conf_dir</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>LD_LIBRARY_PATH=${hadoop_home}/lib/native</value>
    </property>
    <property>
        <name>test.build.data</name>
        <value>$lustre_path/benchmarks/TestDFSIO</value>
    </property>
    <property>
    <name>mapred.rdma.shuffle.lustre</name>
    <value>1</value>
    </property>
</configuration>
EOF

        fi
    else
        DEST_DIR="/tmp/hadoop_install_"$job_id
        DEST_CONF=$DEST_DIR/etc/hadoop
        DEST_LOG=$lustre_path/logs


echo "export JAVA_HOME=$java_home"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_INSTALL=$DEST_DIR"  >> $conf_dir/hadoop-env.sh
echo "export PATH=$DEST_DIR/bin:$PATH"  >> $conf_dir/hadoop-env.sh
echo "export PATH=$DEST_DIR/sbin:$PATH"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_MAPRED_HOME=$DEST_DIR"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_COMMON_HOME=$DEST_DIR"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_HDFS_HOME=$DEST_DIR"  >> $conf_dir/hadoop-env.sh
echo "export YARN_HOME=$DEST_DIR"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_COMMON_LIB_NATIVE_DIR=$DEST_DIR/lib/native"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_CONF_DIR=$DEST_CONF"  >> $conf_dir/hadoop-env.sh
echo "export hadoop_log_dir=$DEST_LOG"  >> $conf_dir/hadoop-env.sh
echo "export YARN_LOG_DIR=$DEST_LOG"  >> $conf_dir/hadoop-env.sh
echo "export HADOOP_OPTS=-Djava.library.path=$DEST_DIR/lib/native"  >> $conf_dir/hadoop-env.sh
echo "export LD_LIBRARY_PATH=$DEST_DIR/lib/native"  >> $conf_dir/hadoop-env.sh

        if [ $3 -eq 0 ]
                then

##############___core-site.xml___################
cat << EOF > $conf_dir/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.default.name</name>
        <value>file://$lustre_path/namenode</value>
    </property>
    <property>
        <name>fs.local.block.size</name>
        <value>268435456</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>$lustre_path/string_to_change</value>
    </property>
EOF

$test_home/genConfFile.py $user_conf_file $conf_dir/core-site.xml "fs.default.name,fs.local.block.size,hadoop.tmp.dir" C Y

cat << EOF > $conf_dir/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.system.dir</name>
        <value>$lustre_path/mapred/system</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.staging.root.dir</name>
        <value>$lustre_path/mapred/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.staging-dir</name>
        <value>$lustre_path/yarn/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.command-opts</name>
        <value>-Xmx1024m -Dhadoop.conf.dir=$DEST_CONF</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>LD_LIBRARY_PATH=$DEST_DIR/lib/native</value>
    </property>
    <property>
        <name>test.build.data</name>
        <value>$lustre_path/benchmarks/TestDFSIO</value>
    </property>
EOF

$test_home/genConfFile.py $user_conf_file $conf_dir/mapred-site.xml "mapreduce.framework.name,mapreduce.jobtracker.system.dir,mapreduce.jobtracker.staging.root.dir,yarn.app.mapreduce.am.staging-dir,yarn.app.mapreduce.am.command-opts,yarn.app.mapreduce.am.env,test.build.data" M Y


        else

##############___core-site.xml___################
cat << EOF > $conf_dir/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.default.name</name>
        <value>file://$lustre_path/namenode</value>
    </property>
    <property>
        <name>fs.local.block.size</name>
        <value>268435456</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>$lustre_path/string_to_change</value>
    </property>
    <property>
        <name>hadoop.ib.enabled</name>
        <value>true</value>
    </property>
    <property>
        <name>hadoop.roce.enabled</name>
        <value>false</value>
    </property>
</configuration>
EOF


cat << EOF > $conf_dir/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.system.dir</name>
        <value>$lustre_path/mapred/system</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.staging.root.dir</name>
        <value>$lustre_path/mapred/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.staging-dir</name>
        <value>$lustre_path/yarn/staging</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.command-opts</name>
        <value>-Xmx1024m -Dhadoop.conf.dir=$DEST_CONF</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>LD_LIBRARY_PATH=$DEST_DIR/lib/native</value>
    </property>
    <property>
        <name>test.build.data</name>
        <value>$lustre_path/benchmarks/TestDFSIO</value>
    </property>
    <property>
    <name>mapred.rdma.shuffle.lustre</name>
    <value>2</value>
    </property>
</configuration>
EOF

        fi
    fi
else
        while read_dom; do
                if [[ $E == name ]]; then
                        if [[ $C == "fs.defaultFS" ]] || [[ $C == "fs.default.name" ]]; then
                                read_dom
                                read_dom
                                lustre_path=$C
                                break
                        fi
                fi
        done < $conf_dir/core-site.xml
    lustre_path=`echo $lustre_path | sed 's/file://g'`
        if [[ -d $lustre_path ]]; then
                rm -rf $lustre_path
                mkdir $lustre_path
        lfs setstripe -s 256M $lustre_path
        fi

fi

if [ $mode_of_operation -eq 4 ]
then
    for i in $hosts; do ssh $i "if [[ -d $DEST_DIR ]]; then if [[ $DEST_DIR == /tmp* ]]; then rm -rf $DEST_DIR; fi; fi"; done
    for i in $hosts; do ssh $i mkdir $DEST_DIR ; done

    for i in $hosts
    do
               scp -r $hadoop_home/* $i:$DEST_DIR/ >/dev/null
            scp -r $conf_dir/* $i:$DEST_CONF/ >/dev/null
    done

    tmp_index=0
    for i in $hosts
    do
               sed -i "s/string_to_change/temp_${tmp_index}/g" $conf_dir/core-site.xml
            scp $conf_dir/core-site.xml $i:$DEST_DIR/etc/hadoop/
               sed -i "s/temp_.*/string_to_change<\/value>/g" $conf_dir/core-site.xml
               tmp_index=$((tmp_index + 1))
    done
    hadoop_home=$DEST_DIR
    hadoop_log_dir=$DEST_LOG
    conf_dir=$DEST_CONF

    if [ ! -d "$DEST_LOG" ]; then
        mkdir $DEST_LOG
    fi
fi

if [ $start_hadoop -eq 1 ]
then
    #start hadoop
    $hadoop_home/sbin/start-yarn.sh --config $conf_dir
    sleep 30
    bindException=`grep -R 'Address already in use' $hadoop_log_dir/* | wc -l`
    if [ $bindException -gt 0 ]
    then
        $hadoop_home/sbin/stop-yarn.sh --config $conf_dir
        echo "Bind Exception occured.. so retrying.."
        sleep 10
        $hadoop_home/sbin/start-yarn.sh --config $conf_dir
          sleep 30
    fi

    numslaves=`wc -l $conf_dir/slaves | cut -d\  -f1`
    activetrackers=`$hadoop_home/bin/hadoop --config $conf_dir job -list-active-trackers | wc -l`
    COUNTER=0
    while [ $numslaves -ne $activetrackers ]
    do
        if [[ $COUNTER -eq 60 ]]
        then
            echo "All NodeManagers are not alive. Exiting.."
            exit 1
        fi
        sleep 5
        activetrackers=`$hadoop_home/bin/hadoop --config $conf_dir job -list-active-trackers | wc -l`
        COUNTER=$((COUNTER + 1))
    done
fi
