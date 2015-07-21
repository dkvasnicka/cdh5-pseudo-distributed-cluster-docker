FROM nimmis/java:oracle-7-jdk
MAINTAINER Martin Chalupa <chalimartines@gmail.com>

#Base image doesn't start in root
WORKDIR /

#Add the CDH 5 repository
COPY conf/cloudera.list /etc/apt/sources.list.d/cloudera.list
#Set preference for cloudera packages
COPY conf/cloudera.pref /etc/apt/preferences.d/cloudera.pref
#Add repository for python installation
COPY conf/python.list /etc/apt/sources.list.d/python.list

#Add a Repository Key
RUN wget http://archive.cloudera.com/cdh5/ubuntu/trusty/amd64/cdh/archive.key -O archive.key && sudo apt-key add archive.key && \
    sudo apt-get update

#Install CDH package and dependencies
RUN sudo apt-get install -y zookeeper-server && \
    sudo apt-get install -y hadoop-conf-pseudo && \
    sudo apt-get install -y python2.7 && \
    sudo apt-get install -y hue && \
    sudo apt-get install -y maven && \
    sudo apt-get install -y hue-plugins

#Copy updated config files
COPY conf/core-site.xml /etc/hadoop/conf/core-site.xml
COPY conf/hdfs-site.xml /etc/hadoop/conf/hdfs-site.xml
COPY conf/mapred-site.xml /etc/hadoop/conf/mapred-site.xml
COPY conf/hadoop-env.sh /etc/hadoop/conf/hadoop-env.sh
COPY conf/yarn-site.xml /etc/hadoop/conf/yarn-site.xml
COPY conf/hue.ini /etc/hue/conf/hue.ini

#Format HDFS
RUN sudo -u hdfs hdfs namenode -format

# --- Install Oozie from sources
ENV MAVEN_OPTS="-XX:MaxPermSize=1g"
RUN wget http://www.eu.apache.org/dist/oozie/4.2.0/oozie-4.2.0.tar.gz && tar xvf oozie-4.2.0.tar.gz

# The original POM contains a reference to a dead Codehaus repo, which causes the build to fail
COPY conf/oozie-pom.xml oozie-4.2.0/pom.xml

# Make dist
RUN (cd oozie-4.2.0 && bin/mkdistro.sh -DskipTests -Phadoop-2)

# Add Hadoop libs both to the war and to the dist 
ENV OOZIEDIST="/oozie-4.2.0/distro/target/oozie-4.2.0-distro/oozie-4.2.0"
RUN rm -f $OOZIEDIST/oozie-server/webapps/oozie.war
RUN $OOZIEDIST/bin/addtowar.sh \
        -hadoop 2.5.0-cdh5.3.3 /usr/lib/hadoop \ 
        -inputwar $OOZIEDIST/oozie.war \ 
        -outputwar $OOZIEDIST/oozie-server/webapps/oozie.war
RUN mkdir $OOZIEDIST/libext    
RUN unzip $OOZIEDIST/oozie-server/webapps/oozie.war -d $OOZIEDIST/oozie-server/webapps/oozie
RUN cp $OOZIEDIST/oozie-server/webapps/oozie/WEB-INF/lib/*.jar $OOZIEDIST/libext
RUN cp -n $OOZIEDIST/oozie-server/lib/*.jar $OOZIEDIST/libext
RUN rm -rf $OOZIEDIST/oozie-server/webapps/oozie        
COPY conf/oozie-site.xml $OOZIEDIST/conf/oozie-site.xml

# Move into place
RUN cp -R $OOZIEDIST /usr/lib/oozie

# Setup user
RUN sudo mkdir /var/lib/oozie    
RUN sudo adduser \
                  --system \
                  --disabled-login \
                  --group \
                  --home /var/lib/oozie \
                  --gecos "Oozie User" \
                  --shell /bin/false \
                  oozie  >/dev/null 
RUN sudo chown -R oozie:oozie /var/lib/oozie                  
RUN sudo chown -R oozie:oozie /usr/lib/oozie 

# Fetch YARN-compatible Spark, will be set up during start once HDFS is up
RUN wget http://d3kbcqa49mib13.cloudfront.net/spark-1.4.1-bin-hadoop2.4.tgz && tar xvf spark-1.4.1-bin-hadoop2.4.tgz

# --- Oozie install done

COPY conf/run-hadoop.sh /usr/bin/run-hadoop.sh
RUN chmod +x /usr/bin/run-hadoop.sh

RUN sudo -u oozie /usr/lib/oozie/bin/ooziedb.sh create -run

# NameNode (HDFS)
EXPOSE 8020 50070

# DataNode (HDFS)
EXPOSE 50010 50020 50075

# ResourceManager (YARN)
EXPOSE 8030 8031 8032 8033 8088

# NodeManager (YARN)
EXPOSE 8040 8042

# JobHistoryServer
EXPOSE 10020 19888

# Hue
EXPOSE 8888

# Technical port which can be used for your custom purpose.
EXPOSE 9999

CMD ["/usr/bin/run-hadoop.sh"]
