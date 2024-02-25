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
mode_of_operation=$8
java_home=$9
resource_manager=${10}

if [ $resource_manager -eq 1 ]
then
    job_id=$SLURM_JOBID
    hosts=`scontrol show hostnames $SLURM_NODELIST`
else
    job_id=$PBS_JOBID
    hosts=`cat $PBS_NODEFILE`
fi

dir_prefix=hibd_data_
name_dir=$2"/namedir_"$job_id
hadoop_log_dir=$1"/log_"$job_id
lustre_path_dir=$6
ramdisk_path_dir=$7
ssd_path_dir=${12}
hdd_path_dir=${13}
start_hadoop=${11}

if [ -d $name_dir ]
then
    if [[ $name_dir == */namedir* ]]; then
        rm -rf $name_dir
    fi
fi

if [ -d $hadoop_log_dir ]
then
        if [[ $hadoop_log_dir == */log_* ]]; then 
                rm -rf $hadoop_log_dir
        fi
fi

if [[ $lustre_path_dir != null ]]; then
    lustre_path="${lustre_path_dir}/${dir_prefix}${job_id}"
    if [ -d ${lustre_path} ]
    then
        rm -rf ${lustre_path}
    fi
    mkdir ${lustre_path}
fi

if [[ $ramdisk_path_dir != null ]]
then
    ramdisk_path="${ramdisk_path_dir}/${dir_prefix}${job_id}"
    if [ -d ${ramdisk_path} ] && [[ ${ramdisk_path} == *${dir_prefix}* ]]
    then
        rm -rf ${ramdisk_path}
    fi
fi

if [[ $ssd_path_dir != null ]]
then
    ssd_path="${ssd_path_dir}/${dir_prefix}${job_id}"
    if [ -d ${ssd_path} ] && [[ ${ssd_path} == *${dir_prefix}* ]]
    then
        rm -rf ${ssd_path}
    fi
fi

if [[ $hdd_path_dir != null ]]
then
    hdd_path="${hdd_path_dir}/${dir_prefix}${job_id}"
    if [ -d ${hdd_path} ] && [[ ${hdd_path} == *${dir_prefix}* ]]
    then
        rm -rf ${hdd_path}
    fi
fi

mkdir $name_dir $hadoop_log_dir

# if configuration files are NOT provided
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

    if [ $3 -eq 0 ]
    then
        isDataDirSpecified=`grep 'dfs.datanode.data.dir' $user_conf_file | wc -l`
        if [[ $isDataDirSpecified -ne 0 ]]
        then
            datadir=`grep 'dfs.datanode.data.dir' $user_conf_file | awk '{print $3}'`

            if [[ "$datadir" == *","* ]]
            then
                datadircount=`echo $datadir |awk -F"," '{print NF+1}'`

                fulldatadir=`grep 'dfs.datanode.data.dir' $user_conf_file | awk '{print $3}'`

                index=1
                datadir=""
                while [ $index -lt $datadircount ]; do
                        firstdatadir=`echo $fulldatadir | cut -d ',' -f $index`
                    datadir1=$firstdatadir"_"$job_id
                    datadirtoclean=`echo $datadir1 | cut -d ']' -f 2 | cut -d ':' -f 2`
                    for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
                    if [ -z "$datadir" ]
                        then
                                datadir=$datadir1
                        else
                                datadir=$datadir","$datadir1
                        fi
                        let index=index+1
                done
            else
                datadir=$datadir"_"$job_id
                datadirtoclean=`echo $datadir | cut -d ']' -f 2 | cut -d ':' -f 2`
                    for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
            fi
        else
            isTmpDirSpecified=`grep 'hadoop.tmp.dir' $user_conf_file | wc -l`
            if [[ $isTmpDirSpecified -ne 0 ]]
            then
                datadir=`grep 'hadoop.tmp.dir' $user_conf_file | awk '{print $3}'`
                datadir=$datadir"_"$job_id
                datadirtoclean=`echo $datadir | cut -d ']' -f 2 | cut -d ':' -f 2`
                    for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
            elif [ "x$hdd_path" != "x" ]
            then
                datadir="file://"$hdd_path
                datadirtoclean=$hdd_path
                    for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
            fi
        fi
        isRAMDirSpecified=`grep 'dfs.memory.storage' $user_conf_file | wc -l`
        if [[ $isRAMDirSpecified -ne 0 ]]
        then
            ramdirtoclean=`grep 'dfs.memory.storage' $user_conf_file | awk '{print $3}'`
                ramdirtoclean=$ramdirtoclean"_"$job_id
                ramdir="file://"$ramdirtoclean
                    for i in $hosts; do ssh $i "[ -d $ramdirtoclean ] && rm -rf $ramdirtoclean"; done
        elif [ "x$ramdisk_path" != "x" ]
        then
            ramdir="file://"$ramdisk_path
            for i in $hosts; do ssh $i "[ -d $ramdisk_path ] && rm -rf $ramdisk_path"; done
        fi

        if [ $mode_of_operation -eq 2 ]
        then
            isLustreSpecified=`grep 'dfs.rdma.lustre.path' $user_conf_file | wc -l`
            if [[ $isLustreSpecified -ne 0 ]]
            then
                    lustrepath=`grep 'dfs.rdma.lustre.path' $user_conf_file | awk '{print $3}'`
                    lustrepath=$lustrepath"_"$job_id"/"
                    if [[ -d $lustrepath ]]
                    then
                        rm -rf $lustrepath
                    fi
                    mkdir $lustrepath
            elif [ "x$lustre_path" != "x" ]
            then
                lustrepath=$lustre_path
            fi
        fi
    elif [ $3 -eq -1 ]
    then
        if [ "x$hdd_path" != "x" ]
        then
            datadir="file://"$hdd_path
            datadirtoclean=$hdd_path
            for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
        fi

        if [ "x$ssd_path" != "x" ]
        then
            ssddir="file://"$ssd_path
            for i in $hosts; do ssh $i "[ -d $ssd_path ] && rm -rf $ssd_path"; done
        fi

        if [ "x$ramdisk_path" != "x" ]
        then
            ramdir="file://"$ramdisk_path
            for i in $hosts; do ssh $i "[ -d $ramdisk_path ] && rm -rf $ramdisk_path"; done
        fi

        if [ $mode_of_operation -eq 2 ] && [ "x$lustre_path" != "x" ]
        then
            lustrepath=$lustre_path
        fi
    fi

    echo "export JAVA_HOME=$java_home"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_INSTALL=$hadoop_home"  >> $conf_dir/hadoop-env.sh
    echo "export PATH=$hadoop_home/bin:$hadoop_home/sbin:$PATH"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_MAPRED_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_COMMON_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_HDFS_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
    echo "export YARN_HOME=$hadoop_home"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_COMMON_LIB_NATIVE_DIR=$hadoop_home/lib/native"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_CONF_DIR=$conf_dir"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_LOG_DIR=$hadoop_log_dir"  >> $conf_dir/hadoop-env.sh
    echo "export YARN_LOG_DIR=$hadoop_log_dir"  >> $conf_dir/hadoop-env.sh
    echo "export HADOOP_OPTS=-Djava.library.path=$hadoop_home/lib/native"  >> $conf_dir/hadoop-env.sh
    echo "export LD_LIBRARY_PATH=$hadoop_home/lib/native"  >> $conf_dir/hadoop-env.sh

    export conf_dir

    data_dir=""
    if [ "x$datadir" != "x" ]
    then
        data_dir="[DISK]"$datadir
    fi
    if [ "x$ssddir" != "x" ]
    then
        if [ "x$data_dir" == "x" ]
        then
            data_dir="[DISK]"$ssddir
        else
            data_dir="[SSD_DISK]$ssddir, $data_dir"
        fi
    fi
    if [ "x$ramdir" != "x" ]
    then
        if [ "x$data_dir" == "x" ]
        then
            data_dir="[DISK]"$ramdir
        else
            data_dir="[RAM_DISK]$ramdir, $data_dir"
        fi
    fi

    if [ "x$data_dir" == "x" ]
    then
        echo "ERROR: no directories found to configure dfs.datanode.data.dir"
        exit 1
    fi

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
        <value>hdfs://$master:9000</value>
    </property>
EOF

        $test_home/genConfFile.py $user_conf_file $conf_dir/core-site.xml "fs.default.name" C Y

    else
##############___core-site.xml___################
cat << EOF > $conf_dir/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.default.name</name>
        <value>hdfs://$master:9000</value>
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
    fi

##############___mapred-site.xml___#########
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
        <name>yarn.app.mapreduce.am.env</name>
        <value>LD_LIBRARY_PATH=${hadoop_home}/lib/native</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.command-opts</name>
        <value>-Xmx1024m -Dhadoop.conf.dir=$conf_dir</value>
    </property>
EOF

    $test_home/genConfFile.py $user_conf_file $conf_dir/mapred-site.xml "mapreduce.framework.name,yarn.app.mapreduce.am.env,yarn.app.mapreduce.am.command-opts" M Y

    if [ $mode_of_operation -eq 1 ]
    then

#############___hdfs-site.xml___########
cat << EOF > $conf_dir/hdfs-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
        <property>
                <name>dfs.namenode.name.dir</name>
                <value>file://$name_dir</value>
        </property>
        <property>
                <name>dfs.datanode.data.dir</name>
                <value>$data_dir</value>
        </property>
        <property>
                <name>dfs.rdma.hhh.mode</name>
                <value>In-Memory</value>
        </property>
        <property>
                <name>dfs.master</name>
                <value>$master</value>
        </property>
EOF

    elif [ $mode_of_operation -eq 2 ]
    then

    if [ "x$lustrepath" == "x" ]
    then
        echo "ERROR: no directories found to configure dfs.rdma.lustre.path"
        exit 1
    fi

#############___hdfs-site.xml___########
cat << EOF > $conf_dir/hdfs-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
        <property>
                <name>dfs.namenode.name.dir</name>
                <value>file://$name_dir</value>
        </property>
        <property>
                <name>dfs.datanode.data.dir</name>
                <value>$data_dir</value>
        </property>
        <property>
        <name>dfs.rdma.lustre.path</name>
        <value>$lustrepath</value>
        </property>
        <property>
                <name>dfs.rdma.hhh.mode</name>
                <value>Lustre</value>
        </property>
        <property>
                <name>dfs.replication</name>
                <value>1</value>
        </property>
        <property>
                <name>dfs.master</name>
                <value>$master</value>
        </property>
EOF

    else

#############___hdfs-site.xml___########
cat << EOF > $conf_dir/hdfs-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>
        <property>
                <name>dfs.namenode.name.dir</name>
                <value>file://$name_dir</value>
        </property>
        <property>
                <name>dfs.datanode.data.dir</name>
                <value>$data_dir</value>
        </property>
        <property>
                <name>dfs.rdma.hhh.mode</name>
                <value>Default</value>
        </property>
        <property>
                <name>dfs.master</name>
                <value>$master</value>
        </property>
EOF

    fi

    $test_home/genConfFile.py $user_conf_file $conf_dir/hdfs-site.xml "dfs.namenode.name.dir,dfs.datanode.data.dir,dfs.rdma.hhh.mode" H Y

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

else
    while read_dom; do
            if [[ $E == name ]]; then
                    if [[ $C == "dfs.datanode.data.dir" ]]; then
                            read_dom
                            read_dom
                            datadir=$C
                            break
                    fi
            fi
    done < $conf_dir/hdfs-site.xml

        if [[ "$datadir" == *","* ]]
        then
            datadircount=`echo $datadir |awk -F"," '{print NF+1}'`
                fulldatadir=$datadir
                index=1
                datadir=""
                while [ $index -lt $datadircount ]; do
                    firstdatadir=`echo $fulldatadir | cut -d ',' -f $index`
                        datadir1=$firstdatadir
                        datadirtoclean=`echo $datadir1 | cut -d ']' -f 2 | cut -d ':' -f 2`
                        for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
                        let index=index+1
                done
    else
                datadirtoclean=`echo $datadir | cut -d ']' -f 2 | cut -d ':' -f 2`
        for i in $hosts; do ssh $i "[ -d $datadirtoclean ] && rm -rf $datadirtoclean"; done
    fi
        while read_dom; do
                if [[ $E == name ]]; then
                        if [[ $C == "dfs.rdma.lustre.path" ]]; then
                                read_dom
                                read_dom
                                lustre_path=$C
                                break
                        fi
                fi
        done < $conf_dir/hdfs-site.xml
    if [[ -d $lustre_path ]]; then
        rm -rf $lustre_path
        mkdir $lustre_path
    fi

fi

#format namenode
echo "Y" | $hadoop_home/bin/hdfs --config $conf_dir namenode -format

#clear logs
if [[ -d "$hadoop_log_dir" ]]
then
    if [[ "$hadoop_log_dir" == */log*  ]]
    then
        rm -rf $hadoop_log_dir/*
    fi
fi


if [ $start_hadoop -eq 1 ]
then
    #start hadoop
    $hadoop_home/sbin/start-dfs.sh --config $conf_dir
    sleep 30
    $hadoop_home/sbin/start-yarn.sh --config $conf_dir
    sleep 30

    bindException=`grep -R 'Address already in use' $hadoop_log_dir/* | wc -l`
    if [ $bindException -gt 0 ]
    then
        $hadoop_home/sbin/stop-all.sh --config $conf_dir
        echo "Bind Exception occured.. so retrying.."
        sleep 10
        $hadoop_home/sbin/start-dfs.sh --config $conf_dir
        sleep 30
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
            echo "All Node Managers are not alive. Check the logs. Exiting.."
            exit 1
        fi
        sleep 5
        activetrackers=`$hadoop_home/bin/hadoop --config $conf_dir job -list-active-trackers | wc -l`
        COUNTER=$((COUNTER + 1))
    done

    activedatanodes=`$hadoop_home/bin/hdfs --config $conf_dir dfsadmin -report | grep 'Live datanodes' | awk '{print $3}' | tr -d '(:)'`
    COUNTER=0
    while [ "x$activedatanodes" == "x" ] || [ $activedatanodes -ne $numslaves ]
    do
            if [[ $COUNTER -eq 60 ]]
            then
                    echo "All datanodes are not up. Check the logs. Exiting.."
                    exit 1
            fi
            sleep 5
        activedatanodes=`$hadoop_home/bin/hdfs --config $conf_dir dfsadmin -report | grep 'Live datanodes' | awk '{print $3}' | tr -d '(:)'`
        COUNTER=$((COUNTER + 1))
    done
fi
