#!/bin/sh

#  netperf-build.sh
#  netperf-wrapper
#
#  Created by Naylon, John on 08/12/2023.
#  

sudo yum -y install git automake autoconf gcc
git clone https://github.com/HewlettPackard/netperf
cd netperf
sed -s 's/AC_CHECK_SA_LEN(ac_cv_sockaddr_has_sa_len)//' < configure.ac > configure.ac.mod
rm -f ./configure
cp configure.ac.mod configure.ac
aclocal
autoheader
automake --add-missing
autoconf
./configure --disable-omni
make
