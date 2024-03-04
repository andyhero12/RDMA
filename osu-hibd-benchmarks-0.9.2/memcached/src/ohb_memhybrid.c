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
#include <time.h>

/*
 * program description and constants
 */
#define PROGRAM_NAME 	     "OHB Hybrid Micro-benchmarks"
#define PROGRAM_DESCRIPTION  "Hybrid micro-benchmarks for Memcached"
#define VERSION		     "0.9.2"
#define DEFAULT_DB_LATENCY   (1 * 1000.0f) 
#define DEFAULT_MAX_MEM	     (64)
#define DEFAULT_VAL_SZ 	     (4 * 1024)

#define MAX_ITERS	   	(1024 * 1)
#define MAX_SZ 		   	(1024 * 512)
#define MAX_KEY_SZ	   	(16)
#define BENCH_UNIFORM_SCAN      (1)
#define BENCH_NORMAL_SCAN  	(2)

unsigned int randr(unsigned int min, unsigned int max);
void randstring(char * random, size_t length); 

unsigned int randr(unsigned int min, unsigned int max)
{
	struct timeval t1;
	gettimeofday(&t1, NULL);
	srand(t1.tv_usec * t1.tv_sec);
	int randN = rand();
	return randN%(max - min +1) +  min;
} 

/*
 * generate rand string
 */
void randstring(char * randStr, size_t length) {

    static char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.-#'?!";        
    char *randomString = randStr;
    unsigned int n = 0;

    if (length) {
        //randomString = malloc(sizeof(char) * (length +1));

        if (randomString) {            
            for (n = 0;n < length;n++) {            
                int key = rand() % (int)(sizeof(charset) -1);
                randomString[n] = charset[key];
            }

            randomString[length] = '\0';
        }
    }
}

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
  printf("\t--spillfactor=\n");
  printf("\t\tSpill factor (>1.0 preferably). Default is 1.33\n");
  printf("\t--scanmode=\n");
  printf("\t\tPattern for memcached_get. Default is UNIFORM.\n");
  printf("\t\tUNIFORM: All keys are selected at random with equal probability.\n");
  printf("\t\tNORMAL: Some keys queried more frequently that others (similar to normal distribution).\n");
  printf("\t--maxmemory=\n");
  printf("\t\tMaximum server memory (in MB). Default is 64 MB.\n");
  printf("\t--valsize=\n");
  printf("\t\tValue Size of key/value pairs (in bytes). Default is 4KB. Key size fixed to 16 Bytes.\n");
  printf("\t--misspenalty=\n");
  printf("\t\tAdditional Latency (E.g. database access latency) to fetch key/value pair\n"); 
  printf("\t\twhen it is a miss in memcached (in ms). Default is 1.5 ms.\n");
  printf("\t--verbose\n");
  printf("\t\tDisplay more verbose output for micro-benchmark.\n");
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
static int opt_verbose=0;
static char * opt_order= NULL;
static char *opt_servers= NULL;
static uint32_t opt_flags= 0;
static time_t opt_expires= 0;
static int opt_maxmemory= DEFAULT_MAX_MEM;
static float opt_fspill= 1.33f;
static float opt_dblatency= 2000.0f; //in micro-seconds
static int opt_valsize= DEFAULT_VAL_SZ;

#define verbose(format, ...) do {                 \
    if (opt_verbose)                              \
        fprintf(stderr, format, ##__VA_ARGS__);   \
} while(0)

/* micro-benchmark options */
enum ohb_options {
  OPT_SERVERS= 's',
  OPT_VERSION= 'V',
  OPT_VERBOSE= 'v',
  OPT_HELP= 'h',
  OPT_MAXMEM= 'm',
  OPT_VALSIZE= 'z',
  OPT_DBLAT= 'd',
  OPT_FSPILL= 'f',
  OPT_SCANMODE = 'o'
};

typedef enum ohb_options ohb_options;

/* parse user-specified options */
static void options_parse(int argc, char *argv[])
{
  int option_indx= 0;
  int option_rv;

  static struct option long_options[]=
    {
      {(const char*)"version", no_argument, NULL, OPT_VERSION},
      {(const char*)"verbose", no_argument, NULL, OPT_VERBOSE},
      {(const char*)"help", no_argument, NULL, OPT_HELP},
      {(const char*)"servers", required_argument, NULL, OPT_SERVERS},
      {(const char*)"maxmemory", required_argument, NULL, OPT_MAXMEM},
      {(const char*)"valsize", required_argument, NULL, OPT_VALSIZE},
      {(const char*)"spillfactor", required_argument, NULL, OPT_FSPILL},
      {(const char*)"misspenalty", required_argument, NULL, OPT_DBLAT},
      {(const char*)"scanmode", required_argument, NULL, OPT_SCANMODE},
      {0, 0, 0, 0},
    };

  while (1)
  {
    option_rv= getopt_long(argc, argv, "Vvhdsmzfo:", long_options, &option_indx);

    if (option_rv == -1) break;

    switch (option_rv)
    {
    case 0:
      break;
    case OPT_VERSION: /* --version or -V */
      version_command(PROGRAM_NAME);
      break;
    case OPT_VERBOSE: /* --version or -V */
      opt_verbose= 1;
      break;
    case OPT_HELP: /* --help or -h */
      help_command(PROGRAM_NAME); 
      break;
    case OPT_SERVERS: /* --servers or -s */
      opt_servers= strdup(optarg);
      break;
    case OPT_MAXMEM: /* --maxmemory */
      opt_maxmemory= atoi(optarg);
      if(opt_maxmemory < 0) {
	fprintf(stderr, "Max. Server Memory specified incorrect. Reverting to default (64 MB).\n");
	opt_dblatency= DEFAULT_MAX_MEM;
      }
      break;
    case OPT_VALSIZE: /* --valsize */
      opt_valsize= atoi(optarg);
      if(opt_valsize < 0) {
	fprintf(stderr, "Max. Value Size specified incorrect. Reverting to default (64 MB).\n");
	opt_dblatency= DEFAULT_MAX_MEM;
      }
      break;
    case OPT_FSPILL: /* --spillfactor */
      opt_fspill= atof(optarg);
      break;
    case OPT_DBLAT: /* --dblatency */
      opt_dblatency= atof(optarg) * 1000.0f;
      if(opt_dblatency < 0.0f ) {
	fprintf(stderr, "Miss Penalty specified incorrect. Reverting to default (1 ms).\n");
	opt_dblatency= DEFAULT_DB_LATENCY;
      }
      break;
    case OPT_SCANMODE: /* --scanmode */
      opt_order= strdup(optarg);
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
char my_value[MAX_SZ];

/* Main fuction for OHB Micro-benchmarks */
int main(int argc, char *argv[])
{
    int benchmark_type = BENCH_UNIFORM_SCAN;
    memcached_st *memc;
    memcached_return_t rc;
    memcached_server_st *servers;

    int i, sz, iters=1000;
    int success_puts = 0, success_gets = 0, total_gets = 0;
    int failed_puts = 0, failed_gets = 0, total_puts = 0;
    int64_t total_time=0, begin=0, end=0;

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
     * obtain micro-benchmark retrieve order
     */
    if(NULL == opt_order){
	    fprintf(stderr, "Please specify the micro-benchmark type.\n");
	    fprintf(stderr, "Use --scanmode=<UNIFORM|NORMAL>.\n");
	    fprintf(stderr, "For more information, use --help.\n");
	    return -1; 
    } else {
	    if(0 == strcmp(opt_order, "UNIFORM")){
		    benchmark_type = BENCH_UNIFORM_SCAN; 
	    } else if(0 == strcmp(opt_order, "NORMAL")){
		    benchmark_type = BENCH_NORMAL_SCAN;
	    } else { 
		    fprintf(stderr, "Micro-benchmark scan mode not known.\n");
		    fprintf(stderr, "Options: UNIFORM | NORMAL.\n");
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

    verbose( "Running OHB Hybrid Benchmark with following:\n");
    verbose( "Spill Factor= %.2f\n", opt_fspill);
    verbose( "Maximumm Server Memory= %d MB\n", opt_maxmemory);
    verbose( "Value Size= %d KB\n", opt_valsize/1024);
    verbose( "Miss Penalty= %f us\n", opt_dblatency);

    /*
     * Run micro-benchmark 
     */ 
    size_t val_len;
    uint32_t flags;
    memset(my_value, 'v', MAX_SZ);
    sz = opt_valsize;

    /* Set Micro-benchmark: run 1000 iterations of memcached_set 
     * 		            for value sizes 1B to 512KB 
     */
    char suffix[40];
    uint8_t nsuffix = (uint8_t)snprintf(suffix, 40, " %d %d\r\n", opt_flags, sz);
    unsigned int item_size = (MAX_KEY_SZ + 1) + nsuffix + sz + 2;
    iters= opt_fspill * ((opt_maxmemory * 1024 * 1024L) / sz);
    /*
     * Some margin for error calculation: 15%
     */
    iters = (int)(iters - iters*0.15f - 25);
    verbose("Loading memcached with %d items of size %u\n", iters, item_size);

    char **memc_keys= malloc(sizeof(char*) * iters);
    for(i=0; i<iters; i++){
	    memc_keys[i] = malloc(sizeof(char) * (MAX_KEY_SZ + 1));
	    randstring(memc_keys[i], MAX_KEY_SZ);
	    rc= memcached_set(memc, memc_keys[i], MAX_KEY_SZ, 
			    my_value, (size_t)sz,
			    opt_expires, opt_flags);
	    total_puts++;
	    if(rc == MEMCACHED_SUCCESS) {
		    /* display performance latency numbes for each message size */
		    success_puts++;
	    }
	    else {
		    failed_puts++;
	    }
    }
    verbose( "Done loading memcached with %d items of size %u\n", iters, item_size);
    verbose( "Successful puts: %d\n", success_puts);
    verbose( "Failed puts: %d\n", failed_puts);

    //Create the pattern to query
    if(BENCH_UNIFORM_SCAN == benchmark_type) { //uniform distribution
	    int pattern_size= MAX_ITERS;
	    verbose( "memcached_get attempts to fetch %d items of size %u (with full-scan like distribution)\n", pattern_size, item_size);
	    srand(time(NULL));
	    //GET according to a pattern 
	    for(i=0; i< pattern_size; i++){
		    total_gets++;
		    int indx = rand()%iters;
		    begin = TIME();
		    char *ret = memcached_get(memc, memc_keys[indx], MAX_KEY_SZ, &val_len, &flags, &rc);
		    end = TIME();
		    if(rc == MEMCACHED_SUCCESS && ret != NULL) {
			    /* display performance latency numbes for each message size */
			    success_gets++;
			    total_time += (end-begin);
			    free(ret);
		    }
		    else {
			    failed_gets++;
			    total_time += ((end-begin) + opt_dblatency); 
		    }
	    }
    } else { //normal distribution
	    int pattern_size= MAX_ITERS;
	    int j= 0, _20p= (int) (iters * 0.20f); 
	    /*
 	     * Query the first 80% of the keys more frequently (80% of MAX_ITERS)
 	     * Query the latest 20% less frequently (20% of MAX_ITERS)
 	     */
	    int _20pstart= 0, _20pend= _20pstart + iters - _20p; 
	    int niters= (int)(pattern_size * 0.20f);
	    int freq_iters= (int)((pattern_size * 0.80f) / (pattern_size * 0.20f));
	    int r2= _20pend + 1;

	    verbose( "memcached_get attempts to fetch %d items of size %u (with Zipf like distribution)\n", pattern_size, sz);
	    for(i=0; i< niters; i++){
		    for(j = 0; j<freq_iters; j++) {
			    int indx = randr(_20pstart, _20pend) % iters;
			    total_gets++;
			    begin = TIME();
			    memcached_get(memc, memc_keys[indx], MAX_KEY_SZ, &val_len, &flags, &rc);
			    end = TIME();
			    if(rc == MEMCACHED_SUCCESS) {
				    /* display performance latency numbes for each message size */
				    success_gets++;
				    total_time += (end-begin);
			    }
			    else {
				    failed_gets++;
				    total_time += ((end-begin) + opt_dblatency); 
			    }
		    }
		    int indx= iters-2;
		    indx= randr(0, r2) % iters;
		    total_gets++;
		    begin = TIME();
		    memcached_get(memc, memc_keys[indx], MAX_KEY_SZ, &val_len, &flags, &rc);
		    end = TIME();
		    if(rc == MEMCACHED_SUCCESS) {
			    /* display performance latency numbes for each message size */
			    success_gets++;
			    total_time += (end-begin);
		    }
		    else {
			    failed_gets++;
			    total_time += ((end-begin) + opt_dblatency); 
		    }
	    }
    }

    float avglatency= (1.0f * total_time / total_gets);
    float success_rate = ((100.0f * success_gets) / total_gets);
    if(!opt_verbose) 
	fprintf(stderr, "%10i byte:\t%11.2f usecs\t%11.2f%c success rate\n", sz, avglatency, success_rate, '%');
    verbose("\nKey/value size= %i(+16) Bytes\n", sz);
    verbose("Total gets= %d\n", total_gets);
    verbose("Total average latency= %.2f usecs\n", avglatency);
    verbose("Successful gets= %d\n", success_gets);
    verbose("Failed gets= %d\n", failed_gets);
    verbose("Success Rate for gets= %.2f\n", success_rate);

    //cleanup
    for(i=0; i<iters; i++) {
	    free(memc_keys[i]);
    } 
    free(memc_keys);
    //cleanup

    /* free memcached and other related structs */ 
    memcached_free(memc);

    if (opt_servers)
	    free(opt_servers);

    return 0;
}

