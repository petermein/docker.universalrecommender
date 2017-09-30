FROM ubuntu
MAINTAINER Peter Mein

# Environment variables
ENV PIO_VERSION 0.11.0
ENV SPARK_VERSION 1.5.1
ENV ELASTICSEARCH_VERSION 1.4.4
ENV HBASE_VERSION 1.0.0
ENV UNIVERSAL_RECOMMENDER 0.6.0

# Base paths
ENV PIO_HOME /PredictionIO-${PIO_VERSION}-incubating
ENV PATH=${PIO_HOME}/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# Install other dependencies
RUN apt-get update \
    && apt-get install -y --auto-remove --no-install-recommends curl git openjdk-8-jdk libgfortran3 python-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install prediction.io itself
RUN curl -O http://apache.cs.uu.nl/incubator/predictionio/${PIO_VERSION}-incubating/apache-predictionio-${PIO_VERSION}-incubating.tar.gz \
    && mkdir apache-predictionio-${PIO_VERSION}-incubating \
    && tar -xvzf apache-predictionio-${PIO_VERSION}-incubating.tar.gz -C apache-predictionio-${PIO_VERSION}-incubating \
    && rm apache-predictionio-${PIO_VERSION}-incubating.tar.gz \
    && cd apache-predictionio-${PIO_VERSION}-incubating \
    && ./make-distribution.sh

RUN tar zxvf /apache-predictionio-${PIO_VERSION}-incubating/PredictionIO-${PIO_VERSION}-incubating.tar.gz -C /
RUN rm -r /apache-predictionio-${PIO_VERSION}-incubating
RUN mkdir /${PIO_HOME}/vendors

# Add prediction.io configuration
COPY files/pio-env.sh ${PIO_HOME}/conf/pio-env.sh

# Install Spark
RUN curl -O http://d3kbcqa49mib13.cloudfront.net/spark-${SPARK_VERSION}-bin-hadoop2.6.tgz \
    && tar -xvzf spark-${SPARK_VERSION}-bin-hadoop2.6.tgz -C ${PIO_HOME}/vendors \
    && rm spark-${SPARK_VERSION}-bin-hadoop2.6.tgz

# Install Elasticsearch
RUN curl -O https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz \
    && tar -xvzf elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz -C ${PIO_HOME}/vendors \
    && rm elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz \
    && echo 'cluster.name: predictionio' >> ${PIO_HOME}/vendors/elasticsearch-${ELASTICSEARCH_VERSION}/config/elasticsearch.yml \
    && echo 'network.host: 127.0.0.1' >> ${PIO_HOME}/vendors/elasticsearch-${ELASTICSEARCH_VERSION}/config/elasticsearch.yml

# Install HBase
RUN curl -O http://archive.apache.org/dist/hbase/hbase-${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz \
    && tar -xvzf hbase-${HBASE_VERSION}-bin.tar.gz -C ${PIO_HOME}/vendors \
    && rm hbase-${HBASE_VERSION}-bin.tar.gz
COPY files/hbase-site.xml ${PIO_HOME}/vendors/hbase-${HBASE_VERSION}/conf/hbase-site.xml
RUN sed -i "s|VAR_PIO_HOME|${PIO_HOME}|" ${PIO_HOME}/vendors/hbase-${HBASE_VERSION}/conf/hbase-site.xml \
    && sed -i "s|VAR_HBASE_VERSION|${HBASE_VERSION}|" ${PIO_HOME}/vendors/hbase-${HBASE_VERSION}/conf/hbase-site.xml

#Install depencies
RUN pip install -U setuptools \
    && pip install predictionio datetime

#Clone the universal recommender
RUN git clone https://github.com/actionml/universal-recommender.git /ur \
    && cd /ur \
    && git checkout tags/${UNIVERSAL_RECOMMENDER}

#Copy engine file
COPY files/engine.json /ur/engine.json

#Copy pio-env 
COPY files/pio-env.sh ${PIO_HOME}/conf/pio-env.sh

# Expose HTTP ports (event server and recommendation server)
EXPOSE 7070 8000