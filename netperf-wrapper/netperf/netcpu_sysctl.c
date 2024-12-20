/*
#  Copyright 2021 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

char   netcpu_sysctl_id[]="\
@(#)netcpu_sysctl.c  Version 2.6.0";

#if HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdio.h>
#include <unistd.h>
# include <string.h>

# include <stdlib.h>

#if HAVE_INTTYPES_H
# include <inttypes.h>
#else
# if HAVE_STDINT_H
#  include <stdint.h>
# endif
#endif

#if TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# if HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif
#if HAVE_LIMITS_H
# include <limits.h>
# ifndef LONG_LONG_MAX
#  define LONG_LONG_MAX LLONG_MAX
# endif /* LONG_LONG_MAX */
#endif

#ifdef __NetBSD__
#define	CP_TIME_TYPE	uint64_t
#else
#define	CP_TIME_TYPE	long
#endif

#include <errno.h>

/* need to have some sort of check for sys/sysctl.h versus sysctl.h */
#include <sys/sysctl.h>


/* this has been liberally cut and pasted from <sys/resource.h> on
   FreeBSD. in general, this would be a bad idea, but I don't want to
   have to do a _KERNEL define to get these and that is what
   sys/resource.h seems to want. raj 2002-03-03 */
#define CP_USER         0
#define CP_NICE         1
#define CP_SYS          2
#define CP_INTR         3
#define CP_IDLE         4
#define CPUSTATES       5


#include "netsh.h"
#include "netlib.h"

static CP_TIME_TYPE lib_start_count[CPUSTATES];
static CP_TIME_TYPE lib_end_count[CPUSTATES];

void
cpu_util_init(void)
{
  return;
}

void
cpu_util_terminate(void)
{
  return;
}

int
get_cpu_method(void)
{
  return SYSCTL;
}

static void
get_cpu_time(CP_TIME_TYPE *cpu_time)
{
  size_t cpu_time_len = CPUSTATES * sizeof (cpu_time[0]);

  if (sysctlbyname("kern.cp_time", cpu_time, &cpu_time_len, NULL, 0) == -1) {
      fprintf (stderr, "Cannot get CPU time!\n");
      exit (1);
  }
}

/* calibrate_sysctl  - perform the idle rate calculation using the
   sysctl call - typically on BSD */

float
calibrate_idle_rate(int iterations, int interval)
{
  return sysconf (_SC_CLK_TCK);
}

float
calc_cpu_util_internal(float elapsed_time)
{
  CP_TIME_TYPE sum_idle, sum_busy;
  int i;

  memset(&lib_local_cpu_stats, 0, sizeof(lib_local_cpu_stats));

  for (sum_busy = 0, i = 0; i < CPUSTATES; i++) {
    if (i != CP_IDLE)
      sum_busy += lib_end_count[i] - lib_start_count[i];
  }

  sum_idle = lib_end_count[CP_IDLE] - lib_start_count[CP_IDLE];
  lib_local_cpu_stats.cpu_util = (float)sum_busy / (float)(sum_busy + sum_idle);
  lib_local_cpu_stats.cpu_util *= 100.0;

  return lib_local_cpu_stats.cpu_util;

}
void
cpu_start_internal(void)
{
  get_cpu_time(lib_start_count);
}

void
cpu_stop_internal(void)
{
  get_cpu_time(lib_end_count);
}
