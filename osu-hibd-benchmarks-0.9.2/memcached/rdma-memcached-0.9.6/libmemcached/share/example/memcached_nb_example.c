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
#include <libmemcached-1.0/memcached.h>

#define VALUE_LEN 8 

int main(int argc, char *argv[])
{
    memcached_server_st *memc_servers = NULL;
    memcached_st *memc = NULL;
    memcached_return rc;

    const char *key= "KEY";
    char *value= (char*)malloc(1 + VALUE_LEN);
    value[VALUE_LEN] = '\0'; 

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

    /* perform a ISET operation */
    memcpy(value, "VALUE123", VALUE_LEN);
    memcached_request_st *setreq = memcached_request_create(memc, value, strlen(value), 0);
    rc= memcached_iset(memc, key, strlen(key), setreq, (time_t)0, (uint32_t)0);
    if(rc == MEMCACHED_SUCCESS) 
        memcached_wait(memc, setreq);
    /* check for success on completion */
    if (rc == MEMCACHED_SUCCESS) {
        fprintf(stderr,"Key stored successfully\n");
       // free(value);
        memcached_request_free(memc, setreq);
    } else {
        fprintf(stderr,"Couldn't store key: %s\n",memcached_strerror(memc, rc));
        exit(-1);
    }

    /* perform a IGET operation */
    memcached_request_st *getreq = memcached_request_create(memc, NULL, 0, 0);
    rc = memcached_iget(memc, key, strlen(key), getreq); 
    if(rc == MEMCACHED_SUCCESS) 
        while((rc = memcached_test(memc, getreq)) == MEMCACHED_IN_PROGRESS);
    if (rc == MEMCACHED_SUCCESS) {
        fprintf(stderr,"Value retrieved successfully. "
                       "Key = %s, Value = %s\n", key, (char *)getreq->value);
        free(getreq->value);
        memcached_request_free(memc, getreq);
    } else {
        fprintf(stderr,"Couldn't get key: %s\n", memcached_strerror(memc, rc));
        exit(-1);
    }

    /* perform a ISET operation */
    memcpy(value, "VALUE123", VALUE_LEN);
    setreq = memcached_request_create(memc, value, strlen(value), 0);
    rc= memcached_bset(memc, key, strlen(key), setreq, (time_t)0, (uint32_t)0);
    if(rc == MEMCACHED_SUCCESS) 
        memcached_wait(memc, setreq);
    /* check for success on completion */
    if (rc == MEMCACHED_SUCCESS) {
        fprintf(stderr,"Key stored successfully\n");
       // free(value);
        memcached_request_free(memc, setreq);
    } else {
        fprintf(stderr,"Couldn't store key: %s\n",memcached_strerror(memc, rc));
        exit(-1);
    }

    /* perform a IGET operation */
    getreq = memcached_request_create(memc, NULL, 0, 0);
    rc = memcached_bget(memc, key, strlen(key), getreq); 
    if(rc == MEMCACHED_SUCCESS) 
        while((rc = memcached_test(memc, getreq)) == MEMCACHED_IN_PROGRESS);
    if (rc == MEMCACHED_SUCCESS) {
        fprintf(stderr,"Value retrieved successfully. "
                       "Key = %s, Value = %s\n", key, (char *)getreq->value);
        free(getreq->value);
        memcached_request_free(memc, getreq);
    } else {
        fprintf(stderr,"Couldn't get key: %s\n", memcached_strerror(memc, rc));
        exit(-1);
    }

    memcached_free(memc);
    return 0;
}
