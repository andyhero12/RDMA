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

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>
#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <libmemcached/memcached.h>
#include <sys/time.h>

/*
 * program description and constants
 */
#define PROGRAM_NAME 	     "OHB Micro-benchmarks"
#define PROGRAM_DESCRIPTION  "Micro-benchmarks for Memcached"
#define VERSION		     "0.9.2"

#define MAX_SZ 		     (512*1024)
#define BENCH_PURE_SET       (1)
#define BENCH_PURE_GET       (2)
#define BENCH_MIX_SET_GET    (3)
#define BENCH_ALL	     (4)

/*
 * time function to measure latency 
 */
#define TIME() getMicrosecondTimeStamp()
static int64_t getMicrosecondTimeStamp()
{
    int64_t retval;
    struct timeval tv;
    if (gettimeofday(&tv, NULL)) {
        perror("gettimeofday");
        abort();
    }
    retval = ((int64_t)tv.tv_sec) * 1000000 + tv.tv_usec;
    return retval;
}

/*
 * OHB Micro-benchmark version
 */
static void version_command(const char *command_name)
{
  printf("%s v%s\n", command_name, VERSION);
  exit(EXIT_SUCCESS);
}

/*
 * OHB Micro-benchmark help
 */
static void help_command(const char * command_name) {
  printf("%s (v%s)\n", command_name, VERSION);
  printf("%s\n\n", PROGRAM_DESCRIPTION);
  printf("Current options. A '=' means the option takes a value.\n\n");

  printf("\t--servers=\n");
  printf("\t\tList which servers you wish to connect to.\n");
  printf("\t--benchmark=<SET|GET|MIX|ALL>\n");
  printf("\t\tSpecify OHB Micro-benchmark type.\n");
  printf("\t\tSupported micro-benchmarks:\n");
  printf("\t\t\tSET - OHB Set Micro-benchmark\n");
  printf("\t\t\t      Micro-benchmark for memcached set operations\n");
  printf("\t\t\tGET - OHB Get Micro-benchmark\n");
  printf("\t\t\t      Micro-benchmark for memcached get operations\n");
  printf("\t\t\tMIX - OHB Mix Micro-benchmark\n");
  printf("\t\t\t      Micro-benchmark for memcached set/get mix\n");
  printf("\t\t\tALL - Run all three OHB Micro-benchmarks\n");
  printf("\t--version\n");
  printf("\t\tDisplay the version of the application and then exit.\n");
  printf("\t--help\n");
  printf("\t\tDisplay help and then exit.\n");
  printf("\n");
  exit(EXIT_SUCCESS);
 }

/*
 * OHB Micro-benchmark options and parser
 */
static int opt_binary=1;
static char *opt_servers= NULL;
static uint32_t opt_flags= 0;
static time_t opt_expires= 0;
static char *opt_benchmark= NULL;

/* micro-benchmark options */
enum ohb_options {
  OPT_SERVERS= 's',
  OPT_VERSION= 'V',
  OPT_HELP= 'h',
  OPT_BENCHMARK= 'b'
};

typedef enum ohb_options ohb_options;

/* parse user-specified options */
static void options_parse(int argc, char *argv[])
{
  int option_index= 0;
  int option_rv;

  static struct option long_options[]=
    {
      {(const char*)"version", no_argument, NULL, OPT_VERSION},
      {(const char*)"help", no_argument, NULL, OPT_HELP},
      {(const char*)"servers", required_argument, NULL, OPT_SERVERS},
      {(const char*)"benchmark", required_argument, NULL, OPT_BENCHMARK},
      {0, 0, 0, 0},
    };

  while (1)
  {
    option_rv= getopt_long(argc, argv, "Vhvds:", long_options, &option_index);

    if (option_rv == -1) break;

    switch (option_rv)
    {
    case 0:
      break;
    case OPT_VERSION: /* --version or -V */
      version_command(PROGRAM_NAME);
      break;
    case OPT_HELP: /* --help or -h */
      help_command(PROGRAM_NAME); 
      break;
    case OPT_SERVERS: /* --servers or -s */
      opt_servers= strdup(optarg);
      break;
    case OPT_BENCHMARK: /* --benchmark */
      opt_benchmark= strdup(optarg);
      break;
    case '?':
      /* getopt_long already printed an error message. */
      exit(1);
    default:
      abort();
    }
  }
}

/*
 * key/value pair to be used for micro-benchmark tests
 */
const char *my_key1 = "my_key1";
const char *my_key2 = "my_key2";
char my_value[MAX_SZ];

/* Main fuction for OHB Micro-benchmarks */
int main(int argc, char *argv[])
{
    int benchmark_type = BENCH_PURE_GET;
    memcached_st *memc;
    memcached_return_t rc;
    memcached_server_st *servers;

    int return_code= 0, i, sz, iters=1000;
    int64_t begin=0, end=0;

    /*
     * parse user-define parameter, mainly the server list and 
     * micro-benchmark type
     */ 
    options_parse(argc, argv);

    /* 
     * create memcached object for the micro-benchmark
     */
    memc= memcached_create(NULL);

    /* 
     * obtain micro-benchmark type 
     */
    if(NULL == opt_benchmark){
        fprintf(stderr, "Please specify the micro-benchmark type.\n");
        fprintf(stderr, "Use --benchmark=<SET|GET|MIX|ALL>.\n");
        fprintf(stderr, "For more information, use --help.\n");
        return -1; 
    } else {
        if(0 == strcmp(opt_benchmark, "SET")){
            benchmark_type = BENCH_PURE_SET;
        } else if(0 == strcmp(opt_benchmark, "GET")){
            benchmark_type = BENCH_PURE_GET;
        } else if(0 == strcmp(opt_benchmark, "MIX")){
            benchmark_type = BENCH_MIX_SET_GET;
        } else if(0 == strcmp(opt_benchmark, "ALL")){
            benchmark_type = BENCH_ALL;
        } else { 
            fprintf(stderr, "Micro-benchmark type not known.\n");
            fprintf(stderr, "Options: SET | GET | MIX | ALL.\n");
            return -1;
        }
    } 

    /* 
     * connect to memcached servers specified   
     */
    if (!opt_servers)
    {
        fprintf(stderr, "Please specify one or more memcached servers.\n");
        fprintf(stderr, "Use --servers==<SERVER[:PORT]>.\n");
        fprintf(stderr, "For more information, use --help.\n");
        exit(1);
    }
    if (opt_servers)
        servers= memcached_servers_parse(opt_servers);
    else
        servers= memcached_servers_parse(argv[--argc]);
    memcached_server_push(memc, servers);
    memcached_server_list_free(servers);
    memcached_behavior_set(memc, MEMCACHED_BEHAVIOR_BINARY_PROTOCOL,
            (uint64_t)opt_binary);
    memcached_behavior_set(memc, MEMCACHED_BEHAVIOR_TCP_NODELAY,
                                    (uint64_t)1);

    /*
     * Run micro-benchmark 
     */ 
    switch(benchmark_type){

        case BENCH_PURE_SET: /* OHB Set Micro-benchmark */
        case BENCH_ALL:
            {
                fprintf(stderr, "Running OHB Set Micro-benchmark\n");
                memset(my_value, 'v', MAX_SZ);

                for(sz=1; sz<=MAX_SZ; sz*=2){

		    /* Set Micro-benchmark: run 1000 iterations of memcached_set 
 		     * 		            for value sizes 1B to 512KB 
 		     */
                    begin = TIME();
                    for(i=0; i<iters; i++){
                        rc= memcached_set(memc, my_key1, strlen(my_key1),
                                my_value, (size_t)sz,
                                opt_expires, opt_flags);
                    }
                    end = TIME();
		    if(rc == MEMCACHED_SUCCESS) {
		        /* display performance latency numbes for each message size */
                    	fprintf(stderr, "%10i byte:\t%11.2f usecs\n", sz, (1.0f * (end-begin)) / ((iters)));
		    }
		    else {
		    	fprintf(stderr, "FAILED: %10i byte: unsuccessful run\n", sz);
			return_code = -1;
		    }
                }
		if(benchmark_type == BENCH_PURE_SET)
                	break;
            }

        case BENCH_PURE_GET:
            {
                size_t val_len;
                uint32_t flags;
                char *ret;

                fprintf(stderr, "Running OHB Get Micro-benchmark\n");

                memset(my_value, 'v', MAX_SZ);

                for(sz=1; sz<=MAX_SZ; sz*=2){

                    rc= memcached_set(memc, my_key1, strlen(my_key1),
                            my_value, (size_t)sz,
                            opt_expires, opt_flags);

		    /* Get Micro-benchmark: run 1000 iterations of memcached_get 
 		     * 		            for value sizes 1B to 512KB 
 		     */
                    begin = TIME();
                    for(i=0; i<iters; i++){
                        ret = memcached_get(memc, my_key1, strlen(my_key1),
                                &val_len, &flags, &rc);
                        if(NULL==ret){
			    break;
                        }
			free(ret);
                    }
                    end = TIME();
		    if(rc == MEMCACHED_SUCCESS) {
		        /* display performance latency numbes for each message size */
                    	fprintf(stderr, "%10i byte:\t%11.2f usecs\n", sz, (1.0f * (end-begin)) / ((iters)));
		    } else{
		    	fprintf(stderr, "FAILED: %10i byte: unsuccessful run\n", sz);
			return_code = -1;
		    }
                }  
		if(benchmark_type == BENCH_PURE_GET)
                	break;
            }


        case BENCH_MIX_SET_GET:
            {
                size_t val_len;
                uint32_t flags;
                char *ret = NULL;

                fprintf(stderr, "Running OHB Mix Micro-benchmark (Mixed Get/Set Operations with 90:10 ratio)\n");
                memset(my_value, 'v', MAX_SZ);

                for(sz=1; sz<=MAX_SZ; sz*=2){

		    /* Mix Micro-benchmark: run 1000 iterations of memcached_set and memcached_get
 		     * 		            for value sizes 1B to 512KB 
 		     * 		            perform 1 set for every 10 get operations
 		     */
                    begin = TIME();
                    for(i=0; i<iters/10; i++){

                        /* set */
                        rc= memcached_set(memc, my_key1, strlen(my_key1),
                                my_value, (size_t)sz,
                                opt_expires, opt_flags);
                        if (rc != MEMCACHED_SUCCESS){
			    break;
                        }

                        /* get */
			int j = 0;
			for(j = 0;j<9;j++) {
                        	ret = memcached_get(memc, my_key1, strlen(my_key2),
                                	&val_len, &flags, &rc);
                        	if(NULL==ret){
			   		break;
                        	}
				free(ret);
			}
                    }
                    end = TIME();
		    if(rc == MEMCACHED_SUCCESS && ret != NULL) {
		        /* display performance latency numbes for each message size */
                    	fprintf(stderr, "%10i byte:\t%11.2f usecs\n", sz, (1.0f * (end-begin)) / ((iters*1.0f)));
			return_code = 0;
		    } else {
		    	fprintf(stderr, "FAILED: %10i byte: unsuccessful run\n", sz);
			return_code = -1;
		   }
                }
                break;
            }

	default:
	    fprintf(stderr, "Invalid benchmark type\n");
    }

    /* free memcached and other related structs */ 
    memcached_free(memc);

    if (opt_servers)
        free(opt_servers);

    return return_code;
}

