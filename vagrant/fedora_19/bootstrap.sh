#!/usr/bin/env bash

sudo yum update -y
sudo yum install gcc kernel-devel kernel-headers dkms make bzip2 perl nodejs npm python-pip git python-devel mongodb-server -y
pip install virtualenv
mkdir vespa && cd vespa
git init
git clone http://gitlab.labs/v3spa/ide.git
cd ide
git submodule update --init
sudo npm install -g gulp
sudo npm install
virtualenv vespa
source vespa/bin/activate
sudo pip install -r requirements.txt 
cd external/d3hive
sudo npm install 
gulp
cd -
gulp
cd ~/vespa/ide
mkdir mongodb

#mongod --dbpath ~/vespa/ide/mongodb &
#~/vespa/ide/api/bin/lobster-server &
#~/vespa/ide/vespa.py &
