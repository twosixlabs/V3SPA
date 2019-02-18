FROM centos

RUN yum install -y make gcc

RUN yum install -y python git setools-devel setools-libs bzip2-devel bison \
               flex python-devel swig \
               libsepol libsepol-devel libsepol-static libselinux-python \
               libselinux-static redhat-rpm-config zlib-devel
# removed python-tornado from yum install - will be installed as part of pip -r requirements.txt

RUN yum install -y epel-release 

RUN yum install -y nodejs 

RUN yum install -y python2-pip

RUN pip install --upgrade pip

RUN curl -sSL https://get.haskellstack.org/ | sh

ENV PATH=/root/.local/bin:$PATH

RUN pip install networkx setuptools

RUN npm install -g gulp

RUN mkdir /vespa

RUN git clone https://github.com/invincealabs/V3SPA.git /vespa/V3SPA

WORKDIR /vespa/V3SPA

RUN git submodule update --init

RUN npm install
 
RUN pip install -r requirements.txt

RUN gulp
 
WORKDIR /vespa/V3SPA/lobster

RUN sed -e 's/extra-deps: \[\]/extra-deps:\n- base-orphans-0@sha256:c1fc192cbcdcdb513ef87755cb5ee4efaea54aec0dfa715a3c681dffb4cf431b/' -i /vespa/V3SPA/lobster/v3spa-server/stack.yaml

RUN make

ENV PATH=/vespa/V3SPA/lobster/v3spa-server/dist/bin:$PATH

WORKDIR /vespa
RUN git clone https://github.com/TresysTechnology/setools.git
WORKDIR /vespa/setools
RUN git checkout 4.0.0
RUN python setup.py install

WORKDIR /vespa

RUN mkdir tmp tmp/bulk tmp/bulk/log tmp/bulk/refpolicy tmp/bulk/tmp tmp/bulk/projects

COPY vespa.ini.docker /vespa/V3SPA/etc/vespa.ini.local

COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

COPY wait-for-it.sh /

RUN chmod +x /wait-for-it.sh

ENTRYPOINT ["sh", "-c", "/docker-entrypoint.sh" ]

