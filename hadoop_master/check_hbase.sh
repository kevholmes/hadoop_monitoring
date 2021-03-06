#!/bin/bash
#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#

user=""
secure="false"
keytab=""
while getopts ":u:k:s" opt; do
  case $opt in
    u)
      user=$OPTARG;
      ;;
    k)
      keytab=$OPTARG;
      ;;
    s)
      secure="true";
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 3
      ;;
    :)
      echo "UNKNOWNOption -$OPTARG requires an argument." >&2
      exit 3
      ;;
  esac
done

outfile="/tmp/nagios-hbase-check.out"
curtime=`date +"%F-%H-%M-%S"`
fname="nagios-hbase-check-${curtime}"

if [[ "$user" == "" ]]; then
  echo "INVALID: user argument not specified";
  exit 3;
fi
if [[ "$keytab" == "" ]]; then 
  keytab="/homes/$user/$user.headless.keytab"
fi

if [[ "$secure" == "true" ]]; then
  sudo -u $user -i "/usr/kerberos/bin/kinit -kt $keytab $user" > ${outfile} 2>&1
fi

output=`echo status | sudo -u $user /usr/bin/hbase --config /etc/hbase shell`
(IFS='')
tmpOutput=$(echo $output | grep -v '0 servers')
if [[ "$?" -ne "0" ]]; then 
  echo "CRITICAL: No region servers are running";
  exit 2; 
fi
echo disable \'nagios_test_table\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell > ${outfile} 2>&1
echo drop \'nagios_test_table\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell > ${outfile} 2>&1
echo create \'nagios_test_table\', \'family\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell > ${outfile} 2>&1
echo put \'nagios_test_table\', \'row01\', \'family:col01\', \'value1\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell > ${outfile} 2>&1
output=`echo scan \'nagios_test_table\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell`
(IFS='')
tmpOutput=$(echo $output | grep -v '1 row(s) in')
if [[ "$?" -ne "1" ]]; then 
  echo "CRITICAL: Error populating HBase table";
  exit 2; 
fi
echo disable \'nagios_test_table\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell > ${outfile} 2>&1
echo drop \'nagios_test_table\' | sudo -u $user /usr/bin/hbase --config /etc/hbase shell > ${outfile} 2>&1

echo "OK: HBase transaction completed successfully"
exit 0;
