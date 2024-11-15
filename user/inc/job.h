#pragma once
#include "client.h"
#include "req.h"
#include "res.h"

#include <stdbool.h>

typedef struct job {
  char     id[JOB_ID_SIZE + 1];
  uint8_t  cmd;
  bool     complete;
  char    *data;
  uint64_t packet_id;
  uint64_t data_pos;
  uint64_t data_size;

  client_t *client;
  req_t     req;
  res_t     res;
} job_t;

#define job_debug(f, ...) debug("(job: %s) " f, job->id, ##__VA_ARGS__)
#define job_debug_err(f, ...) debug_err("(job: %s) " f, job->id, ##__VA_ARGS__)

bool job_new(job_t *job, client_t *client); // init the job
void job_free(job_t *job);

void job_data_set(job_t *job, char *data, uint64_t data_size);
void job_data_clear(job_t *job);

bool job_recv(job_t *job, bool allow_new);
bool job_send(job_t *job, bool require_ack); // send the results of a job
