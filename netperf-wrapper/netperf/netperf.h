// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

#ifndef netperf_h
#define netperf_h

void
netperf_main(int argc, const char *argv[], 
             void *user_data,
             void (*setup_complete)(int port, void *user_data),
             void (*exitfunction)(const char *t, void *user_data));

void
actual_send_omni_inner(void *user_data, 
                       void (*latency_result)(double x, unsigned long y, const char *t, void *user_data));

void
scan_omni_args(int argc, char *argv[]);

void
send_mtcp_rr(char remote_host[]);

void
shutdown_control(void);


#endif /* netperf_h */
