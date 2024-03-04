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
package edu.osu.hibd.ohb.spark

import java.util.Random

import org.apache.spark.{SparkConf, SparkContext}
import org.apache.spark.SparkContext._

/**
  * Usage: SortByTest [numMappers] [numKVPairs] [KeySize] [numReducers]
  */
object SortByTest {
  def main(args: Array[String]) {
    val sparkConf = new SparkConf().setAppName("SortBy Test")
    var numMappers = if (args.length > 0) args(0).toInt else 2
    var numKVPairs = if (args.length > 1) args(1).toInt else 1000
    var valSize = if (args.length > 2) args(2).toInt else 1000
    var numReducers = if (args.length > 3) args(3).toInt else numMappers
    var shuffleDataSize = numMappers * numKVPairs * (valSize + 4)

    println("[OHB-Spark] Running OHB SparkBench SortByTest")
    val sc = new SparkContext(sparkConf)

    val pairs1 = sc.parallelize(0 until numMappers, numMappers).flatMap { p =>
      val ranGen = new Random
      var arr1 = new Array[(Int, Array[Byte])](numKVPairs)
      for (i <- 0 until numKVPairs) {
        val byteArr = new Array[Byte](valSize)
        ranGen.nextBytes(byteArr)
        arr1(i) = (ranGen.nextInt(Int.MaxValue), byteArr)
      }
      arr1
    }.cache()
    // Enforce that everything has been calculated and in cache
    pairs1.count()

    print(pairs1.sortByKey(true,numReducers).count())
    sc.stop()
  }
}
