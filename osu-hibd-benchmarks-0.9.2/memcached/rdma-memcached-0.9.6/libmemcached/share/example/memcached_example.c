/* Copyright (c) 2011-2017, The Ohio State University. All rights
 * reserved.
 *
 * This file is part of the RDMA for Memcached software package
 * developed by the team members of The Ohio State University's
 * Network-Based Computing Laboratory (NBCL), headed by Professor
 * Dhabaleswar K. (DK) Panda.
 *
 * For detailed copyright and licensing information, please refer to
 * the copyright file COPYRIGHT in the top level directory.
 *
*/

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <libmemcached/memcached.h>

int main(int argc, char *argv[])
{
    memcached_server_st *memc_servers = NULL;
    memcached_st *memc = NULL;
    memcached_return rc;
    uint32_t flags;
    size_t value_len;

    char *key= "KEY";
    char *value= "VALUE123";

    if(2 != argc){
        fprintf(stderr, "Error in parsing arguments, usage: ./example <servername:port>\n");
        exit(-1);
    }

    /* create a new memcached instance */
    memc= memcached_create(NULL);

    /* parse memcached servers list: passed as a string */
    memc_servers= memcached_servers_parse(argv[1]);
    if(NULL == memc_servers){
        fprintf(stderr, "Error in parsing arguments, usage: ./example <servername:port>\n");
        exit(-1);
    }

    /* connect to the memcached servers */
    rc= memcached_server_push(memc, memc_servers);
    if (MEMCACHED_SUCCESS != rc) {
        fprintf(stderr,"Could not connect to servers: %s\n",
                memcached_strerror(memc, rc));
        exit(-1);
    }
    memcached_server_list_free(memc_servers);

    /* perform a SET operation */
    rc= memcached_set(memc, key, strlen(key), value, strlen(value), 
                      (time_t)0, (uint32_t)0);
    if (rc == MEMCACHED_SUCCESS) {
        fprintf(stderr,"Key stored successfully\n");
    } else {
        fprintf(stderr,"Couldn't store key: %s\n",memcached_strerror(memc, rc));
        exit(-1);
    }

    /* perform a GET operation */
    char * valueRec = memcached_get(memc, key, strlen(key), &value_len,
                                    &flags, &rc);
    if (rc == MEMCACHED_SUCCESS) {
        fprintf(stderr,"Key retrieved successfully. Key = %s, Value = %s\n", 
                key, valueRec);
        free(valueRec);
    } else {
        fprintf(stderr,"Couldn't store key: %s\n", 
                memcached_strerror(memc, rc));
        exit(-1);
    }
 
    memcached_free(memc);
    return 0;
}
