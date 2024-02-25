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
    specify the hadoop conf dir (default: ""). If user provides this directory,
    then the conf files are chosen from this directory. Otherwise, the conf files
    are generated automatically with/without user provided configuration with
    flag '-u'

    -j <dir>
    specify jdk installation or JAVA_HOME (default: ""). If user does not
    provide this, then java installation is searched in the environment.

    -u <file>
    specify a file containing all the configurations for hadoop installation
    (default: n/a). Each line of this file must be formatted as below:
    "<C|H|M|Y>\t<parameter_name>\t<parameter_value>"
    C = core-site.xml, H = hdfs-site.xml, M = mapred-site.xml, Y = yarn-site.xml

    -l <dir>
    specify the Lustre path to use for hhh-l, mrlustre-local, and mrlustre-lustre
    modes (default: "")

    -r <dir>
    specify the ram disk path to be used for hhh and hhh-m modes (default: /dev/shm)

    -s 
    specify to start hadoop after installation and configuration

    -S
    specify the SSD path to be used for all modes (default: "")

    -H
    specify the HDD path to be used for all modes (default: "")

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
start_hadoop=0
args=`getopt sc:h:m:j:u:l:r:S:H:? $*`

# init
lustre_path="null"
ramdisk_path="null"
ssd_path="null"
hdd_path="null"

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

        -j) shift;
            java_home=$1
            shift;;

        -u) shift;
            user_conf_file=$1
            shift;;

        -l) shift;
            lustre_path=$1
            shift;;

        -r) shift;
            ramdisk_path=$1
            shift;;

        -s) shift;
            start_hadoop=1
            ;;

        -S) shift;
            ssd_path=$1
            shift;;

        -H) shift;
            hdd_path=$1
            shift;;
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
                if [[ $hadoop_home == */bin/hadoop ]]; then
                        hadoop_home=`echo $hadoop_home | sed 's/\/bin\/hadoop//g'`  
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
                if [ "x$user_conf_file" == "x" ]
                then
                        user_conf_file="null"
                        hadoop_confs_provided=-1
                else
                        if [ ! -f "$user_conf_file" ]
                        then
                                echo "No user conf provided. Choosing conf for hhh mode." >&2
                                hadoop_confs_provided=-1
                                user_conf_file="null"
                        fi
                fi
                if [ ! -d "$test_home/conf_$job_id" ]
                then
                        mkdir $test_home/conf_$job_id
                else
                        rm -rf $test_home/conf_$job_id
                        mkdir $test_home/conf_$job_id
                fi
                hadoop_conf_dir=$test_home/conf_$job_id
        else
                hadoop_conf_dir=$HADOOP_CONF_DIR
                hadoop_confs_provided=1
                if [ "x$user_conf_file" == "x" ]
                then
                        user_conf_file="null"
                else
                        echo "Hadoop conf dir is provided, discarding -u flag." >&2
                        user_conf_file="null"
                fi
        fi
else
        hadoop_confs_provided=1
        if [ "x$user_conf_file" == "x" ]
        then
                user_conf_file="null"
        else
                echo "Hadoop conf dir is provided, discarding -u flag." >&2
                user_conf_file="null"
        fi
fi


# Detecting the mode of operation for Hadoop. Possible values are 
# HHH-Default=0, HHH-M=1, HHH-L=2, MRLUSTRE-LOCAL=3, MRLUSTRE-LUSTRE=4

hadoop_mode=-1
running_mode="${running_mode,,}"
if [ "$running_mode" == "hhh-l" ] 
then
    hadoop_mode=2
    if [ $hadoop_confs_provided -ne 1 ]
    then
        if [ "x$lustre_path" == "x" ]
        then
            if [ "x$LUSTRE_PATH" == "x" ]
            then
                echo "Lustre path must be provided for HHH-L mode of operation. Exiting.." >&2
                print_usage
                exit 1
            else
                lustre_path=$LUSTRE_PATH
            fi
        fi
            if [ "x$ramdisk_path" == "x" ]
            then
                if [ "x$RAMDISK_PATH" == "x" ]
            then
                        if [ ! -d /dev/shm ]
                        then
                                echo "Ram disk path need to be mentioned for HHH. Exiting.." >&2
                                print_usage
                                exit 1
                        else
                                ramdisk_path="/dev/shm"
                        fi
            else
                ramdisk_path=$RAMDISK_PATH
            fi
            fi
    else
        lustre_path="null"
        ramdisk_path="null"
    fi
elif [ "$running_mode" == "hhh-m" ] 
then
    hadoop_mode=1
    if [ $hadoop_confs_provided -ne 1 ]
    then
                if [ "x$ramdisk_path" == "x" ]
                then
                        if [ "x$RAMDISK_PATH" == "x" ]
                        then
                                if [ ! -d /dev/shm ]
                                then
                                        echo "Ram disk path need to be mentioned for HHH-M mode of operation. Exiting.." >&2
                                        print_usage
                                        exit 1
                                else
                                        ramdisk_path="/dev/shm"
                                fi
                        else
                                ramdisk_path=$RAMDISK_PATH
                        fi
                fi
    else
        ramdisk_path="null"
    fi
    lustre_path="null"
elif [ "$running_mode" == "mrlustre-local" ] 
then
    hadoop_mode=3
    if [ $hadoop_confs_provided -ne 1 ]
    then
                if [ "x$lustre_path" == "x" ]
                then
                        if [ "x$LUSTRE_PATH" == "x" ]
                        then
                                echo "Lustre path must be provided for MRoLustre-local mode of operation. Exiting.." >&2
                                print_usage
                                exit 1
                        else
                                lustre_path=$LUSTRE_PATH
                        fi
                fi
    else
        lustre_path="null"
        ramdisk_path="null"
    fi
elif [ "$running_mode" == "mrlustre-lustre" ]
then
    hadoop_mode=4
    if [ $hadoop_confs_provided -ne 1 ]
    then
                if [ "x$lustre_path" == "x" ]
                then
                        if [ "x$LUSTRE_PATH" == "x" ]
                        then
                                echo "Lustre path must be provided for MRoLustre-lustre mode of operation. Exiting.." >&2
                                print_usage
                                exit 1
                        else
                                lustre_path=$LUSTRE_PATH
                        fi
                fi
    else
        lustre_path="null"
        ramdisk_path="null"
    fi
else
    hadoop_mode=0
    if [ $hadoop_confs_provided -ne 1 ]
    then
            if [ "x$ramdisk_path" == "x" ]
            then
                        if [ "x$RAMDISK_PATH" == "x" ]
                        then
                                if [ ! -d /dev/shm ]
                                then
                                        echo "Ram disk path need to be mentioned for HHH. Exiting.." >&2
                                        print_usage
                                        exit 1
                                else
                                        ramdisk_path="/dev/shm"
                                fi
                        else
                                ramdisk_path=$RAMDISK_PATH
                        fi
            fi
    else
        ramdisk_path="null"
    fi
    lustre_path="null"
fi

# set SSD path and HDD path for all modes
if [ $hadoop_confs_provided -ne 1 ]
then
    if [ "x$ssd_path" == "x" ]
    then
        ssd_path="null"
        if [ "x$SSD_PATH" != "x" ]
        then
            ssd_path=$SSD_PATH
        fi
    fi
    if [ "x$hdd_path" == "x" ]
    then
        hdd_path="null"
        if [ "x$HDD_PATH" != "x" ]
        then
            hdd_path=$HDD_PATH
        fi
    fi
else
    ssd_path="null"
    hdd_path="null"
fi

# Check if JAVA_HOME is provided. If not, search and use.

if [ "x$java_home" == "x" ]
then
    if [ "x$JAVA_HOME" == "x" ]
    then
        java_home=`which java`
        if [ "x$java_home" == "x" ]
        then
            echo "No Java found. Exiting.. " >&2
            print_usage
            exit 1
        fi
        java_version=`$java_home -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q'`
        if [ $java_version -lt 16 ]
        then
            echo "No appropriate java found. Version greater than 1.5 required. Exiting.. " >&2
            print_usage
            exit 1
        fi
        if [[ $java_home == */bin/java ]]; then
            java_home=`echo $java_home | sed 's/\/bin\/java//g'`
        fi
    else
        java_home=$JAVA_HOME
    fi
else
    export JAVA_HOME=$java_home
fi

# Based on hadoop_mode appropriate launcher selected. 
if [ $hadoop_mode -ge 3 ]
then
    $test_home/mrlustre_launcher.sh $test_home $hadoop_home $hadoop_confs_provided $hadoop_conf_dir $user_conf_file $lustre_path $hadoop_mode $java_home $resource_manager $start_hadoop $ssd_path $hdd_path
else
    $test_home/hhh_launcher.sh $test_home $hadoop_home $hadoop_confs_provided $hadoop_conf_dir $user_conf_file $lustre_path $ramdisk_path $hadoop_mode $java_home $resource_manager $start_hadoop $ssd_path $hdd_path
fi
