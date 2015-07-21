#!/bin/bash

service hadoop-hdfs-namenode start
service hadoop-hdfs-datanode start

sudo -u hdfs hadoop fs -mkdir -p /tmp/hadoop-yarn/staging/history/done_intermediate
sudo -u hdfs hadoop fs -chown -R mapred:mapred /tmp/hadoop-yarn/staging
sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
sudo -u hdfs hadoop fs -mkdir -p /var/log/hadoop-yarn
sudo -u hdfs hadoop fs -chown yarn:mapred /var/log/hadoop-yarn

service hadoop-yarn-resourcemanager start
service hadoop-yarn-nodemanager start
service hadoop-mapreduce-historyserver start

sudo -u hdfs hadoop fs -mkdir -p /user/hdfs
sudo -u hdfs hadoop fs -chown hdfs /user/hdfs

#init oozie
sudo -u hdfs hadoop fs -mkdir /user/oozie
sudo -u hdfs hadoop fs -chown oozie:oozie /user/oozie
sudo -u oozie /usr/lib/oozie/bin/oozie-setup.sh sharelib create -fs hdfs://localhost:8020 -locallib /usr/lib/oozie/oozie-sharelib-4.2.0.tar.gz
SHARELIB=$(sudo -u oozie hadoop fs -ls share/lib | tail -n 1 | awk '{print $NF}')
sudo -u oozie hadoop fs -rm $SHARELIB/spark/spark*
sudo -u oozie hadoop fs -copyFromLocal /spark-1.4.1-bin-hadoop2.4/lib/spark-assembly-1.4.1-hadoop2.4.0.jar $SHARELIB/spark

sudo -u oozie /usr/lib/oozie/bin/oozied.sh start

service hue start

sleep 1
sudo -u oozie /usr/lib/oozie/bin/oozie admin -sharelibupdate -oozie http://localhost:11000/oozie

# tail log directory
tail -n 1000 -f /var/log/hadoop-*/*.out
