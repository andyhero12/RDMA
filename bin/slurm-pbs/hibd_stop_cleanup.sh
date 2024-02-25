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


# Printing usage of this script.

function print_usage(){
    echo "Usage: $(basename $0) [options]" >&2
    cat <<EOF >&2
    -h <dir> 
        specify location of hadoop installation a.k.a. hadoop home

    -m <hhh | hhh-m | hhh-l | mrlustre-local | mrlustre-lustre>
    specify the mode of operation (default: hhh). For more information, visit
    http://hibd.cse.ohio-state.edu/overview/

    -c <dir>
    specify the hadoop conf dir (default: "").

    -l <dir>
    specify the Lustre path to use for hhh-l, mrlustre-local, and mrlustre-lustre
    modes (default: "")

    -r <dir>
    specify the ram disk path to use for hhh and hhh-m modes (default: /dev/shm)

    -d 
    specify to delete logs and data after hadoop stops

    -?
        show this help message
EOF
}

if [ "x$1" == "x-?" ]
then
  print_usage
  exit 0
fi

# Reading the arguments from the command line.
delete_data=0
args=`getopt dc:h:m:l:r:? $*`

set -- $args
for i
do
    case "$i" in
        -c) shift;
            hadoop_conf_dir=$1
            shift;;

        -h) shift;
            hadoop_home=$1
            shift;;

        -m) shift;
            running_mode=$1
            shift;;

        -l) shift;
            lustre_path=$1
            shift;;

        -r) shift;
            ramdisk_path=$1
            shift;;

    -d) shift;
        delete_data=1
    esac
done

# Detecting current directory and use it as test home.

test_home=`which $0`
test_home=`dirname ${test_home}`
test_home=`cd "$test_home"; pwd`

# Detecting resource manager in the cluster. Currently supporing 
# SLURM=1 and PBS=0

if [ "x$PBS_JOBID" != "x" ]
then
    resource_manager=0
    job_id=$PBS_JOBID
elif [ "x$SLURM_JOBID" != "x" ]
then
    resource_manager=1
    job_id=$SLURM_JOBID
else
    echo "No resource manager. Exiting.." >&2
    print_usage
    exit 1
fi

# Detecting the mode of operation for Hadoop. Possible values are 
# HHH-Default=0, HHH-M=1, HHH-L=2, MRLUSTRE-LOCAL=3, MRLUSTRE-LUSTRE=4

hadoop_mode=-1
running_mode="${running_mode,,}"
if [ "$running_mode" == "hhh-l" ]
then
        hadoop_mode=2
elif [ "$running_mode" == "hhh-m" ]
then
        hadoop_mode=1
elif [ "$running_mode" == "mrlustre-local" ]
then
        hadoop_mode=3
elif [ "$running_mode" == "mrlustre-lustre" ]
then
        hadoop_mode=4
else
        hadoop_mode=0
fi


if [ $hadoop_mode -eq 4 ]
then
        hadoop_home="/tmp/hadoop_install_"$job_id
        hadoop_conf_dir=$hadoop_home/etc/hadoop
fi

# Detecting whether Hadoop is provided. 

if [ "x$hadoop_home" == "x" ]
then
        if [ "x$HADOOP_HOME" == "x" ]
        then
                hadoop_home=`which hadoop`
                if [ "x$hadoop_home" == "x" ]
                then
            echo "No hadoop home provided. Exiting.." >&2
                        print_usage
                        exit 1
                fi
        else
                hadoop_home=$HADOOP_HOME
        fi
else
    export HADOOP_HOME=$hadoop_home
fi

# Check if Hadoop conf dir is specified. If not, create a directory. 

if [ "x$hadoop_conf_dir" == "x" ]
then
    if [ "x$HADOOP_CONF_DIR" == "x" ]
    then
        hadoop_confs_provided=0
        hadoop_conf_dir=$test_home/conf_$job_id
    else
        hadoop_confs_provided=1
        hadoop_conf_dir=$HADOOP_CONF_DIR
    fi
else
    hadoop_confs_provided=1
fi

#stop yarn
$hadoop_home/sbin/stop-yarn.sh --config $hadoop_conf_dir
sleep 10
if [ $hadoop_mode -lt 3 ]
then
    #stop Hadoop
    $hadoop_home/sbin/stop-dfs.sh --config $hadoop_conf_dir
    sleep 10
fi

if [ $delete_data -eq 1 ]
then
    if [ $hadoop_mode -eq 4 ]
    then
        if [ "x$test_home" != "x" ]
        then
                    if [ -d $test_home"/log_"$job_id ]
                    then
                            rm -rf $test_home"/log_"$job_id
            fi
                fi
        if [ "x$lustre_path" != "x" ]
        then
                    if [ -d $lustre_path"/hibd_data_"$job_id ]
                    then
                            rm -rf $lustre_path"/hibd_data_"$job_id
            fi
                fi
        if [ "x$hadoop_home" != "x" ]
        then
            if [ -d $hadoop_home/logs ]
            then
                rm -rf $hadoop_home/logs
            fi
        fi
    else
        if [ "x$hadoop_home" != "x" ]
        then
            if [ -d $hadoop_home"/namedir_"$job_id ]
            then
                rm -rf $hadoop_home"/namedir_"$job_id
            fi
        fi
        if [ "x$test_home" != "x" ]
        then
            if [ -d $test_home"/log_"$job_id ]
            then
                rm -rf $test_home"/log_"$job_id
            fi
        fi
        if [ "x$lustre_path" != "x" ]
        then
            if [ -d $lustre_path"/hibd_data_"$job_id ]
            then
                rm -rf $lustre_path"/hibd_data_"$job_id
            fi
        fi
        if [ "x$ramdisk_path" != "x" ]
        then
            if [ -d $ramdisk_path"/hibd_data_"$job_id ]
            then
                rm -rf $ramdisk_path"/hibd_data_"$job_id
            fi
        fi
        if [ $hadoop_confs_provided -eq 1 ]
        then
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
                                for i in $hosts; do ssh $i "if [[ -d $datadirtoclean ]]; then rm -rf $datadirtoclean; fi"; done
                                let index=index+1
                        done
                else
                        datadirtoclean=`echo $datadir | cut -d ']' -f 2 | cut -d ':' -f 2`
                        for i in $hosts; do ssh $i "if [[ -d $datadirtoclean ]]; then rm -rf $datadirtoclean; fi"; done
                fi
        fi
    fi
fi
