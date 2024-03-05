/* Copyright (c) 2011-2016, The Ohio State University. All rights
 * reserved.
 *    
 * This file is part of the OSU HiBD-Benchmarks software package developed by the
 * team members of The Ohio State University's Network-Based Computing
 * Laboratory (NBCL), headed by Professor Dhabaleswar K. (DK) Panda.
 *  
 * For detailed copyright and licensing information, please refer to the
 * license file LICENSE.txt in the top level OHB directory.
 *  
 */
package edu.osu.hibd.ohb.hdfs;

import java.io.IOException;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.FSDataInputStream;
import org.apache.hadoop.fs.FSDataOutputStream;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.util.StringUtils;

/**
 * HDFS Read Latency Benchmark (SRL)
 */
public class HDFSReadLatency {

	public static final String BENCH_NAME = HDFSReadLatency.class
			.getSimpleName();
	private static int BUFFER_SIZE = 1 * 1024 * 1024; // size of buffer (maximum
														// limit 4MB)
	private static Configuration conf = new Configuration();
	private static boolean verbose = false;
	public static String version = "v0.9.2";

	private static void checkArgs(String confPath, String fileName, int fileSize, int bufSize) {
		if (confPath == null || confPath.equals("")) {
			System.out.println("Hadoop configuration dir path empty!!! "
					+ "Please provide hadoop conf dir path.");
			printHelp();
			System.exit(-1);
		}
		if (fileName.equals("")) {
			System.out.println("File name is empty!!! "
					+ "Please provide a file name.");
			printHelp();
			System.exit(-1);
		}
		if (bufSize < 1 * 1024 * 1024 || bufSize > 4 * 1024 * 1024) {
                        System.out
                                        .println("Buffer size must be betweer 1MB and 4MB (inclusive)!!! "
                                                        + "Please provide a valid buffer size in MB.");
                        printHelp();
                        System.exit(-1);
                }
	}

	private static void execBench(String fileName, int fileSize, int bufSize) {
		long start = 0, end = 0;
		long count = 0;
		int numBytes = 0;

		byte c[] = new byte[bufSize];

		try {
			Path pt = new Path(fileName);
			System.out.println(conf);
			FileSystem fs = FileSystem.get(conf);

			FSDataInputStream in = fs.open(pt); // opens an input stream to the
												// given file

			start = System.nanoTime() / 1000;
			while ((numBytes = in.read(c, 0, bufSize)) > 0) {// reads the file
				count += numBytes;
			}
			in.close(); // close the file
			end = System.nanoTime() / 1000 - start;
		} catch (IOException e) {
			System.out.println("IO Exception occured during file read "
					+ StringUtils.stringifyException(e));
			System.exit(-1);
		}
		double interval = (double) end / 1000000;
		double latency = interval;

		System.out.println();
		System.out.println("# Benchmark Output:");
		System.out.println("File name = " + fileName);
		System.out.println("File size = " + (count / (1024 * 1024)) + "MB");
		System.out.println("Read Latency = " + latency + "s");
	}

	public static void main(String[] args) throws Exception {
		String confPath = "";
		String fileName = "";
		int fileSize = 0;
		int bufSize = BUFFER_SIZE;

		System.out.println("# OSU HADOOP BENCHMARK HDFS Read Latency Test "
				+ version);
		try {
			confPath = System.getProperty("hadoop.conf.dir");

			for (int i = 0; i < args.length; i++) {
				if (args[i].startsWith("-fileName")) {
					fileName = args[++i];
				} else if (args[i].startsWith("-bufSize")) {
					bufSize = Integer.parseInt(args[++i]);
					bufSize = bufSize * 1024 * 1024;
				}
			}
		} catch (Exception e) {
			printHelp();
			System.exit(-1);
		}

		checkArgs(confPath, fileName, fileSize, bufSize); // check user inputs
		printConfigurationParameters(confPath); // print the hdfs configuration
												// parameters
		execBench(fileName, fileSize, bufSize); // execute the read operation
	}

	private static void printConfigurationParameters(String confPath) {
		conf.addResource(new Path(confPath + "/hdfs-site.xml"));
		conf.addResource(new Path(confPath + "/core-site.xml"));

		long blockSize = conf.getLong("dfs.blocksize", 128 * 1024 * 1024);
		short defaultReplication = (short) conf.getInt("dfs.replication", 3);
		String dataDir = conf.get("dfs.datanode.data.dir");

		System.out.println("# Configuration Parameters:");
		System.out.println("Block size: " + blockSize);
		System.out.println("Replication factor: " + defaultReplication);
		System.out.println("Data directory: " + dataDir);
	}

	private static void printHelp() {
		System.out.println();
		System.out.println("# Usage of " + BENCH_NAME + ":");
		System.out.println("Please provide hadoop conf directory!!!");
		System.out.println("Also provide the following arguments: ");

		System.out.println("1. File Name (prefix = -fileName)");
		System.out.println("2. Buffer Size (prefix = -bufSize");
	}
}
