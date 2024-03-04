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
 * HDFS Write Latency Benchmark (SWL)
 */
public class HDFSWriteLatency {

	public static final String BENCH_NAME = HDFSWriteLatency.class
			.getSimpleName();
	public static final long BLOCK_SIZE = 128 * 1024 * 1024;
	private static int BUFFER_SIZE = 1 * 1024 * 1024; // size of buffer (maximum
														// 4MB)
	private static Configuration conf = new Configuration();
	public static final short REPLICATION_FACTOR = 3;
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
		if (fileSize <= 0) {
			System.out.println("File size must be positive!!! "
					+ "Please provide a valid file size.");
			printHelp();
			System.exit(-1);
		}
		if (bufSize < 1 * 1024 * 1024 || bufSize > 4 * 1024 * 1024) {
                        System.out.println("Buffer size must be betweer 1MB and 4MB (inclusive)!!! "+ "Please provide a valid buffer size in MB.");
                        printHelp();
                        System.exit(-1);
                }
	}

	private static void execBench(String fileName, int fileSize, int bufSize) {
		long start = 0, end = 0;
		double count = 0.0;
		byte c[] = new byte[bufSize];
		for (int i = 0; i < bufSize; i++) {
			c[i] = (byte) 'a';
		}
		try {
			Path pt = new Path("/user/" + fileName);
			FileSystem fs = FileSystem.get(conf);

			FSDataOutputStream out = fs.create(pt); //creating an output stream to the file
			count = fileSize / (bufSize / (1024 * 1024));
			start = System.nanoTime() / 1000;

			for (int j = 0; j < (int) count; j++) {
				out.write(c, 0, bufSize); //write the data
			}
			out.close();

			end = System.nanoTime() / 1000 - start;
		} catch (IOException e) {
			System.out.println("IO Exception occured during file write "
					+ StringUtils.stringifyException(e));
			System.exit(-1);
		}
		double interval = (double) end / 1000000;
		double latency = interval;

		System.out.println();
		System.out.println("# Benchmark Output:");
		System.out.println("File size = " + fileSize + "MB");
		System.out.println("Write Latency = " + latency + "s");
	}

	public static void main(String[] args) throws Exception {
		String confPath = "";
		String fileName = "";
		int fileSize = 0;
		long blockSize = BLOCK_SIZE;
		int replicationFactor = REPLICATION_FACTOR;
		boolean blockFlag = false;
		boolean replicationFlag = false;
		int bufSize = BUFFER_SIZE;

		System.out.println("# OSU HADOOP BENCHMARK HDFS Write Latency Test "
				+ version);
		try {
			confPath = System.getProperty("hadoop.conf.dir");

			for (int i = 0; i < args.length; i++) {
				if (args[i].startsWith("-fileName")) {
					fileName = args[++i];
				} else if (args[i].startsWith("-fileSize")) {
					fileSize = Integer.parseInt(args[++i]);
				} else if (args[i].startsWith("-bSize")) {
					blockSize = Long.parseLong(args[++i]);
					blockFlag = true;
				} else if (args[i].startsWith("-rep")) {
					replicationFactor = Integer.parseInt(args[++i]);
					replicationFlag = true;
				} else if (args[i].startsWith("-bufSize")) {
					bufSize = Integer.parseInt(args[++i]);
					bufSize = bufSize * 1024 * 1024;
				}
			}

		} catch (Exception e) {
			printHelp();
			System.exit(-1);
		}

		checkArgs(confPath, fileName, fileSize, bufSize); // check user input
		setConfigurationParameters(confPath, blockSize, replicationFactor,
				blockFlag, replicationFlag);
		printConfigurationParameters();
		execBench(fileName, fileSize, bufSize); // execute the write operation
	}

	private static void printConfigurationParameters() {
		long blockSize = conf.getLong("dfs.blocksize", BLOCK_SIZE);
		short defaultReplication = (short) conf.getInt("dfs.replication",
				REPLICATION_FACTOR);
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
		System.out.println("2. File Size (prefix = -fileSize)");
		System.out.println("3. HDFS Block Size (prefix = -bSize; default "
				+ "block-size will be used if no argument is provided)");
		System.out.println("4. HDFS Replication Factor (prefix = -rep; "
				+ "default replication factor will be used if "
				+ "no argument is provided)");
		System.out.println("5. Buffer Size (prefix = -bufSize");
	}

	private static void setConfigurationParameters(String s, long blockSize,
			int repFactor, boolean bFlag, boolean repFlag) {
		conf.addResource(new Path(s + "/hdfs-site.xml"));
		conf.addResource(new Path(s + "/core-site.xml"));
		if (bFlag) {
			conf.setLong("dfs.blocksize", blockSize);
		}
		if (repFlag) {
			conf.setInt("dfs.replication", repFactor);
		}
	}
}
