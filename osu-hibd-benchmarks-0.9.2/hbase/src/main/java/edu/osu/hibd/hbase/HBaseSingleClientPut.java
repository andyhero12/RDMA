/* Copyright (c) 2011-2016, The Ohio State University. All rights
 * reserved.
 *
 * This file is part of the OSU HiBD-Benchmarks software package
 * developed by the team members of The Ohio State University's
 * Network-Based Computing Laboratory (NBCL), headed by Professor
 * Dhabaleswar K. (DK) Panda.
 *
 * For detailed copyright and licensing information, please refer to
 * the copyright file COPYRIGHT in the top level directory.
 *
*/

package edu.osu.hibd.ohb.hbase;

import java.io.*;
import java.lang.*;
import java.util.Random;

import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.HTableDescriptor;
import org.apache.hadoop.hbase.HColumnDescriptor;
import org.apache.hadoop.hbase.client.HBaseAdmin;
import org.apache.hadoop.hbase.client.Get;
import org.apache.hadoop.hbase.client.HTable;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Result;
import org.apache.hadoop.hbase.client.ResultScanner;
import org.apache.hadoop.hbase.client.Scan;
import org.apache.hadoop.hbase.util.Bytes;

import org.apache.commons.cli.BasicParser;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;

// Put MicroBenchmark 
// Class that has nothing but a main.
// Does a Put against a hbase table.
public class HBaseSingleClientPut {

  public static void main(String[] args) throws IOException {
    
    int MAX_MSG_SIZE = 1 << 20; // Max message size
    int records_num = 10000; // Number of iterations
    int i = 0;
    int msg_size = 1 << 1; // Start message size
    int skip_loop = 2500; // Number of iterations to skip 
    int keyLength = 0;
    String userid = "test-hbase";
    String strUserid = "";
    String strAppend = "";
    long t_start = 0, t_end = 0;
    double latency;
    String autoFlush = "";

    // Parse autoflush option from command-line
    // Usage: -af true/false or --autoflush true/false
    // Default is true
    Options options = new Options();     
    options.addOption("af", "autoflush", true, "Enable/Disable Auto Flush");
    CommandLineParser parser = new BasicParser();
    CommandLine cmd = null;
    try {
        cmd = parser.parse(options, args);
	if (cmd.hasOption("af"))
	    autoFlush = cmd.getOptionValue("af");
	else
	    autoFlush = "true";
    } catch (ParseException e) {
	System.out.println("Error parsing command-line arguments.");
    }

    // We need a configuration object to tell the client where to connect.
    // When we create a HBaseConfiguration, it reads whatever we've set
    // in our hbase-site.xml and hbase-default.xml files, as long as these can
    // be found in the CLASSPATH
    HBaseConfiguration config = new HBaseConfiguration();
    HBaseAdmin admin = new HBaseAdmin(config);

    System.out.printf("Put MicroBenchmark\n", records_num);
    System.out.printf("Message Size\tLatency (us)\n");

    for(; msg_size <= MAX_MSG_SIZE; msg_size*=2)
    {

	// Delete existing table
    	if (admin.tableExists("usertable")){
      	  admin.disableTable("usertable");
      	  admin.deleteTable("usertable");
    	}

        // Create a new table with table name "usertable" and column family "values"
    	HTableDescriptor tableDescripter = new HTableDescriptor("usertable".getBytes());
    	tableDescripter.addFamily(new HColumnDescriptor("Values"));
    	admin.createTable(tableDescripter);
    	HTable table = new HTable(config, "usertable");
	// By default set Auto Flush to true so that each put operation results  in 1 communication
        if (autoFlush.equals("false"))
	  table.setAutoFlush(false);
	else
	  table.setAutoFlush(true); 

	byte[] values = new byte[msg_size];
	for(i=0; i<msg_size; i++)
          values[i]='a';

	// For message sizes more than 64k, use 1k iterations
	// This is to improve performance
	if (msg_size == 1 << 16) {
		records_num = 1000;
		skip_loop = 250;
	}

	// Write records
	for(i=0; i<records_num; i++)
	{
  	  strUserid = "user" + i;
  	  keyLength = strUserid.length();
	  strAppend = userid.substring(keyLength);
	  strUserid = strUserid + strAppend; 
	  Put p = new Put(Bytes.toBytes(strUserid));
	  p.setWriteToWAL(true);
    	  p.add(Bytes.toBytes("Values"), Bytes.toBytes("Field1"), values);
	  // Skip first few iterations (Warm up phase)
	  if(i==skip_loop)
	    t_start=System.nanoTime();
	  table.put(p);
	}

    	t_end = System.nanoTime();
	latency = (t_end - t_start)/(records_num - skip_loop)/1000.0;
	System.out.printf("%8d\t%10.3f\n", msg_size, latency);
    }  
  }
}
