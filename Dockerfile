FROM fedora-base

ADD . /project
WORKDIR /project

RUN npm install -g gulp
RUN git submodule update --init
RUN npm install
RUN mkvirtualenv vespa
RUN pip install -r requirements.txt

