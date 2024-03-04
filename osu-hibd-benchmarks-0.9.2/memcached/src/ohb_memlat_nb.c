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
#include <stdlib.h>             // Needed for exit() and ato*()
#include <math.h>               // Needed for pow()

/*
 * program description and constants
 */
#define PROGRAM_NAME 	     "OHB Non-Blocking API Micro-benchmarks"
#define PROGRAM_DESCRIPTION  "Non-Blocking API Micro-benchmarks for HiBD RDMA-Memcached"
#define VERSION		     "0.9.2"
#define DEFAULT_MAX_MEM	     (64)
#define DEFAULT_VAL_SZ 	     (4 * 1024)

#define MAX_ITERS	   	(1024 * 1)
#define MAX_SZ 		   	(1024 * 512)
#define MAX_KEY_SZ	   	(16)
#define BENCH_UNIFORM_SCAN      (1)
#define BENCH_NORMAL_SCAN  	(2)
#define RAND_SEED               1

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
  printf("\t--reqtype=\n");
  printf("\t\tAPI to use for benchmarking. Options are iset/bset/iget/bget\n");
  printf("\t--progresstype=\n");
  printf("\t\tProgress API to use for non-blocking requests. Options are wait or test.\n");
  printf("\t--pattern=\n");
  printf("\t\tPattern for memcached_get/iget/bget. Default is \"random\".\n");
  printf("\t\trandom: All keys are selected at random with equal probability.\n");
  printf("\t\tzipf: Keys selected using zipf distribution.\n");
  printf("\t--maxmemory=\n");
  printf("\t\tMaximum server memory (in MB). Default is 64 MB.\n");
  printf("\t--numgets=\n");
  printf("\t\tTotal number of key/value pairs to fetch from Memcached servers.\n");
  printf("\t--valsize=\n");
  printf("\t\tValue size of key/value pairs (in bytes). Default is 4KB. Key size fixed to 16 Bytes.\n");
  printf("\t--reqthresh=\n");
  printf("\t\tNumber of pending non-blocking requests allowed.\n");
  printf("\t\tMust be smaller than <max-memory>/<value-size>.\n");
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
static int opt_iters=0;
static char *opt_servers= NULL;
static uint32_t opt_flags= 0;
static time_t opt_expires= 0;
static int opt_maxmemory= DEFAULT_MAX_MEM;
static char *opt_reqtype= NULL;
static char *opt_pattern= NULL;
static char *opt_progtype= NULL;
static int opt_reqthresh= 32; //number of requests
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
  OPT_PROG= 'd',
  OPT_REQTYPE= 'r',
  OPT_THRESH= 'f',
  OPT_ITERS= 't',
  OPT_PATTERN = 'o'
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
      {(const char*)"pattern", required_argument, NULL, OPT_PATTERN},
      {(const char*)"reqtype", required_argument, NULL, OPT_REQTYPE},
      {(const char*)"progresstype", required_argument, NULL, OPT_PROG},
      {(const char*)"reqthresh", required_argument, NULL, OPT_THRESH},
      {(const char*)"numgets", required_argument, NULL, OPT_ITERS},
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
      }
      break;
    case OPT_VALSIZE: /* --valsize */
      opt_valsize= atoi(optarg);
      if(opt_valsize < 0) {
	fprintf(stderr, "Max. Value Size specified incorrect. Reverting to default (64 MB).\n");
      }
      break;
    case OPT_PATTERN: /* --reqtype */
      opt_pattern= strdup(optarg);
      break;
    case OPT_REQTYPE: /* --reqtype */
      opt_reqtype= strdup(optarg);
      break;
    case OPT_PROG: /* --progtype */
      opt_progtype= strdup(optarg);
      break;
    case OPT_THRESH: /* --reqthresh */
      opt_reqthresh= atoi(optarg);
      break;
    case OPT_ITERS: /* --numgets */
      opt_iters= atoi(optarg);
      break;
    case '?':
      /* getopt_long already printed an error message. */
      exit(1);
    default:
      abort();
    }
  }
}

static float ALPHA = 1.01f;

double rand_val(int seed);
//=========================================================================
//= Multiplicative LCG for generating uniform(0.0, 1.0) random numbers    =
//=   - x_n = 7^5*x_(n-1)mod(2^31 - 1)                                    =
//=   - With x seeded to 1 the 10000th x value should be 1043618065       =
//=   - From R. Jain, "The Art of Computer Systems Performance Analysis," =
//=     John Wiley & Sons, 1991. (Page 443, Figure 26.2)                  =
//=========================================================================
double rand_val(int seed)
{
    const long  a =      16807;  // Multiplier
    const long  m = 2147483647;  // Modulus
    const long  q =     127773;  // m div a
    const long  r =       2836;  // m mod a
    static long x;               // Random int value
    long        x_div_q;         // x divided by q
    long        x_mod_q;         // x modulo q
    long        x_new;           // New x value

    // Set the seed if argument is non-zero and then return zero
    if (seed > 0)
    {
        x = seed;
        return(0.0f);
    }

    // RNG using integer arithmetic
    x_div_q = x / q;
    x_mod_q = x % q;
    x_new = (a * x_mod_q) - (r * x_div_q);
    if (x_new > 0)
        x = x_new;
    else
        x = x_new + m;

    // Return a random value between 0.0 and 1.0
    return((double) x / m);
}

//===========================================================================
//=  Function to generate Zipf (power law) distributed random variables     =
//=    - Input: alpha and N                                                 =
//=    - Output: Returns with Zipf distributed random variable              =
//===========================================================================
int zipf(double alpha, const int n);
int zipf(double alpha, int n)
{
    static int first = true;      // Static first time flag
    static double c = 0;          // Normalization constant
    double z;                     // Uniform random number (0 < z < 1)
    double sum_prob;              // Sum of probabilities
    double zipf_value = 0.0f;     // Computed exponential value to be returned
    int    i;                     // Loop counter

    // Compute normalization constant on first call only
    if (first == true)
    {
        for (i=1; i<1+n; i++)
            c = c + (1.0f / pow((double) i, alpha));
        c = 1.0f / c;
        first = false;
    }

    // Pull a uniform random number (0 < z < 1)
    do
    {
      z = rand_val(0);
    } while ((z <= 0) || (z >= 1));

    // Map z to the value
    sum_prob = 0;
    for (i=1; i<1+n; i++)
    {
        sum_prob = sum_prob + c / pow((double) i, alpha);
        if (sum_prob >= z)
        {
            zipf_value = i;
            break;
        }
    }

    // Assert that zipf_value is between 1 and N
    return(zipf_value);
}

/*
 * key/value pair to be used for micro-benchmark tests
 */
char my_value[MAX_SZ];

/* Main fuction for OHB Micro-benchmarks */
int main(int argc, char *argv[])
{
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
     * connect to memcached servers specified   
     */
    if (!opt_servers)
    {
      fprintf(stderr, "Please specify one or more memcached servers.\n");
      fprintf(stderr, "Use --servers==<SERVER[:PORT]>.\n");
      fprintf(stderr, "For more information, use --help.\n");
      exit(1);
    }

    servers= memcached_servers_parse(opt_servers);
    if(MEMCACHED_SUCCESS !=  memcached_server_push(memc, servers)) {
      fprintf(stderr, "Servers not alive: %s\n", opt_servers);
      memcached_server_list_free(servers);
      exit(-1);
    }

    memcached_server_list_free(servers);
    memcached_behavior_set(memc, MEMCACHED_BEHAVIOR_BINARY_PROTOCOL,
		    (uint64_t)opt_binary);
    memcached_behavior_set(memc, MEMCACHED_BEHAVIOR_TCP_NODELAY,
		    (uint64_t)1);

    /*
     * init
     */
    if(opt_reqtype == NULL) 
      opt_reqtype = strdup("iget");
    if(opt_progtype == NULL) 
      opt_progtype = strdup("wait");
    if(opt_pattern == NULL)
      opt_pattern = strdup("random");
    rand_val(RAND_SEED);

    verbose( "Running OHB Non-blocking API Micro-Benchmark with following:\n");
    verbose( "Benchmark = %s\n", opt_reqtype);
    verbose( "Maximum Server Memory= %d MB\n", opt_maxmemory);
    verbose( "Value Size= %d KB\n", opt_valsize/1024);

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
    iters= ((opt_maxmemory * 1024 * 1024L) / sz);
    verbose("Loading memcached with %d items of size %u\n", iters, sz);

    if(iters < opt_reqthresh) {
      fprintf(stderr, "Threshold for requests cannot be greater than the number of puts\n");
      return -1;
    }

    /*
     * Init: non-blocking request structures
     */
    int x = 0;
    bool is_set = false;
    char **memc_keys= malloc(sizeof(char*) * iters);
    memcached_request_st **all_reqs = (memcached_request_st **)malloc(sizeof(memcached_request_st *) * opt_reqthresh);
    for(x = 0; x < opt_reqthresh; x++) {
      all_reqs[x]= memcached_request_create(memc, my_value, (size_t)sz, opt_flags);
    }

    /*
     * set_op: 0 => blocking 1 => iset 2 => bset
     */
    uint8_t set_op = 0;
    uint8_t get_op = 0;
    uint8_t chk_op = 0;
    if(strcmp(opt_reqtype, "iset") == 0) {
      set_op = 1;
      is_set = true;
    }
    else if(strcmp(opt_reqtype, "bset") == 0) {
      set_op = 2;
      is_set = true;
    }

    if(strcmp(opt_reqtype, "iget") == 0) {
      get_op = 1;
    } else if(strcmp(opt_reqtype, "bget") == 0) {
      get_op = 2;
    }

    if(strcmp(opt_progtype, "wait") == 0) {
      chk_op = 1;
    } else if(strcmp(opt_progtype, "test") == 0) {
      chk_op = 2;
    }

    srand(time(NULL));
    if(set_op != 0) { 
      int curr_in_progress = 0;
      begin = TIME();
      for(i=0; i<iters; i++){
        memc_keys[i] = malloc(sizeof(char) * (MAX_KEY_SZ + 1));
        randstring(memc_keys[i], MAX_KEY_SZ);

        /*
         * wait out current requests
         */
        if(curr_in_progress == opt_reqthresh) {
          int x = 0;
          for(x = 0; x < curr_in_progress; x++) {
            if(chk_op == 1) {
              memcached_wait(memc, all_reqs[x]);
            } else if(chk_op == 2) {
              while(MEMCACHED_IN_PROGRESS == memcached_test(memc, all_reqs[x])); 
            }
            if(all_reqs[x]->response == MEMCACHED_SUCCESS) {
              /* display performance latency numbes for each message size */
              success_puts++;
            } else {
              failed_puts++;
            }
          }
          curr_in_progress = 0;
        }

        if(set_op == 1) {
          rc= memcached_iset(memc, memc_keys[i], MAX_KEY_SZ, all_reqs[curr_in_progress], opt_expires, opt_flags);
        } else { 
          rc= memcached_bset(memc, memc_keys[i], MAX_KEY_SZ, all_reqs[curr_in_progress], opt_expires, opt_flags);
        }
        curr_in_progress++;
        total_puts++;
      }
      /*
       * flush out remaining requests
       */
      for(x = 0; x < curr_in_progress; x++) {
        if(chk_op == 1) {
          memcached_wait(memc, all_reqs[x]);
        } else if(chk_op == 2) {
          while(MEMCACHED_IN_PROGRESS == memcached_test(memc, all_reqs[x])); 
        }
        if(all_reqs[x]->response == MEMCACHED_SUCCESS) {
          /* display performance latency numbes for each message size */
          success_puts++;
        } else {
          failed_puts++;
        }
      }
      end = TIME();

    } else { //use default blocking set to warm-up cache
      begin= TIME();
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
        } else {
          failed_puts++;
        }
      }
      end = TIME();
    }

    total_time = (end-begin);
    float avglatency= (1.0f * total_time / total_puts);
    float success_rate = ((100.0f * success_puts) / total_puts);
    if(!opt_verbose) {
      if(is_set == true) 
        fprintf(stderr, "%10i byte:\t%11.2f usecs\t%11.2f%c success rate\n", sz, avglatency, success_rate, '%');
    } else {
      verbose( "Done loading memcached with %d items of size %u\n", iters, sz);
      verbose( "Successful puts: %d\n", success_puts);
      verbose( "Failed puts: %d\n", failed_puts);
      verbose( "Average latency per request: %11.2f\n", avglatency);
    }
      
    /* 
     * exit it only set test
     */
    if(is_set == true) {
      for(x = 0; x < opt_reqthresh; x++) {
        memcached_request_free(memc, all_reqs[x]);
      }
      for(i=0; i<iters; i++) {
        free(memc_keys[i]);
      } 
      free(memc_keys);
      /* free memcached and other related structs */ 
      memcached_free(memc);
      if (opt_servers)
        free(opt_servers);
      return 0;
    }

    total_time =0;

    /* 
     * Get Test: create the pattern to query
     */
    for(x = 0; x < opt_reqthresh; x++) {
      char *mybuf= (char *)malloc(sizeof(char)*(sz+1));
      all_reqs[x]= memcached_request_create(memc, mybuf, 0, 0);
    }

    /*
     * Access KVs in random
     */
    int pattern_size= opt_iters == 0? MAX_ITERS: opt_iters;
    verbose( "memcached_get attempts to fetch %d items of size %u\n", pattern_size, sz);
    //GET according to a pattern

    int pattern_op = 0; 
    if(strcmp(opt_pattern, "random") == 0)
      pattern_op = 0;
    else 
      pattern_op = 1; //zipf
        
    if(get_op == 1 || get_op == 2) { 
      int curr_in_progress = 0;
      for(i=0; i< pattern_size; i++){
        int indx = 0;
        if(pattern_op == 0) indx= rand()%iters;
        else indx= zipf(ALPHA, iters-1);

        /*
         * wait out current requests
         */
        if(curr_in_progress == opt_reqthresh) {
          begin = TIME();
          int x = 0;
          for(x = 0; x < curr_in_progress; x++) {
            if(chk_op == 1) {
              memcached_wait(memc, all_reqs[x]);
            } else if(chk_op == 2) {
              while(MEMCACHED_IN_PROGRESS == memcached_test(memc, all_reqs[x])); 
            }
            if(all_reqs[x]->response == MEMCACHED_SUCCESS) {
              /* display performance latency numbes for each message size */
              success_gets++;
            } else {
              failed_gets++;
            }
          }
          curr_in_progress = 0;
          end = TIME();
          total_time+=end-begin;
        }

        begin = TIME();
        if(get_op == 1)
          rc= memcached_iget(memc, memc_keys[indx], MAX_KEY_SZ, all_reqs[curr_in_progress]);
        else 
          rc= memcached_bget(memc, memc_keys[indx], MAX_KEY_SZ, all_reqs[curr_in_progress]);
        curr_in_progress++;
        total_gets++;
        end = TIME();
        total_time+=end-begin;
      }
      /*
       * flush out remaining requests
       */
      int x = 0;
      begin = TIME();
      for(x = 0; x < curr_in_progress; x++) {
        if(chk_op == 1) {
          memcached_wait(memc, all_reqs[x]);
        } else if(chk_op == 2) {
          while(MEMCACHED_IN_PROGRESS == memcached_test(memc, all_reqs[x])); 
        }
        if(all_reqs[x]->response == MEMCACHED_SUCCESS) {
          /* display performance latency numbes for each message size */
          success_gets++;
        } else {
          failed_gets++;
        }
      }
      end = TIME();
      total_time += (end-begin);
    } else {
      for(i=0; i< pattern_size; i++){
        total_gets++;
        int indx = 0;
        if(pattern_op == 0) indx= rand()%iters;
        else indx= zipf(ALPHA, iters-1);
        begin = TIME();
        char *ret = memcached_get(memc, memc_keys[indx], MAX_KEY_SZ, &val_len, &flags, &rc);
        if(rc == MEMCACHED_SUCCESS && ret != NULL) {
          /* display performance latency numbes for each message size */
          success_gets++;
          free(ret);
        }
        else {
          failed_gets++;
        }
        end = TIME();
        total_time += (end-begin);
      }
    }

    avglatency= (1.0f * total_time / total_gets);
    success_rate = ((100.0f * success_gets) / total_gets);
    if(!opt_verbose) 
	fprintf(stderr, "%10i byte:\t%11.2f usecs\t%11.2f%c success rate\n", sz, avglatency, success_rate, '%');
    verbose("\nKey/value size= %i(+16) Bytes\n", sz);
    verbose("Total gets= %d\n", total_gets);
    verbose( "Average latency per request: %11.2f\n", avglatency);
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
