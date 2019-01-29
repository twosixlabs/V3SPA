V3SPA
=================

[![Black Hat Arsenal](https://www.toolswatch.org/badges/arsenal/2016.svg)](https://www.blackhat.com/us-16/arsenal.html)
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](./LICENSE)

## About

V3SPA is a tool for visualizing and analyzing SELinux and SEAndroid security policies.

To address the challenges in developing and maintaining SELinux security policies, we developed V3SPA (Verification, Validation and Visualization of Security Policy Abstractions). V3SPA creates an abstraction of the underlying security policy using the Lobster domain-specific language, and then tightly integrates exploratory controls and filters with visualizations of the policy to rapidly analyze the policy rules. V3SPA includes several novel analysis modes that change the way policy authors and auditors build and analyze SELinux policies. These modes include: 

1. A mode for differential policy analysis. This plugin shows analysts a visual diff of two versions of a security policy, allowing analysts to clearly see changes made. Using dynamic query filters, analysts can quickly answer questions such as, "What are the changes that affect passwd_t?" 

2. A mode for analyzing information flow, identifying unexpected sets of permissions, and examining the overall design of the policy. This plugin allows users to see the entire policy at once, filter down to see only the components of interest, and execute reachability queries both from and to specified domains.

## Installation

The V3SPA backend has been tested on Fedora 24, and the frontend has been tested in Chrome. V3SPA requires setools v4.

### Manual Installation

To setup the backend on a Fedora box:

    $ sudo dnf install -y python git setools-devel setools-libs bzip2-devel bison flex nodejs python-tornado python-devel mongodb-server swig libsepol libsepol-devel libsepol-static libselinux-python libselinux-static redhat-rpm-config
    $ curl -sSL https://s3.amazonaws.com/download.fpcomplete.com/fedora/24/fpco.repo | sudo tee /etc/yum.repos.d/fpco.repo
    $ sudo dnf -y install zlib-devel stack
    $ sudo pip install virtualenv networkx setuptools
    $ mkdir vespa
    $ cd vespa
    $ git clone https://github.com/invincealabs/V3SPA.git
    $ cd V3SPA
    $ git submodule update --init
    $ sudo npm install -g gulp
    $ sudo npm install
    $ virtualenv vespa
    $ source vespa/bin/activate
    $ pip install -r requirements.txt
    $ gulp

    $ cd lobster
    $ make

    $ cd ../..

    $ git clone https://github.com/TresysTechnology/setools.git
    $ cd setools
    $ git checkout 4.0.0
    $ sudo python setup.py install

    $ mkdir mongodb
    $ mkdir tmp
    $ mkdir tmp/bulk
    $ mkdir tmp/bulk/log
    $ mkdir tmp/bulk/refpolicy
    $ mkdir tmp/bulk/tmp
    $ mkdir tmp/bulk/projects

    $ mongod --dbpath ./mongodb &
    $ python V3SPA/vespa.py &
    $ (cd tmp/bulk && ../../V3SPA/lobster/v3spa-server/dist/v3spa-server) &

At this point you should create the appropriate firewall rules for 
your VM to allow external access to port 8080 if you would like
the service open to clients outside your VM.

### Automated (vagrant) Installation

There is a vagrant file and shell script provided to execute all the steps during provisioning without launching Mongo or the two binaries at the end.

First install these requirements:

 - vagrant
 - VirtualBox

Then run these commands:

    $ git clone https://github.com/invincealabs/V3SPA.git
    $ cd V3SPA
    $ vagrant plugin install vagrant-vbguest
    $ vagrant up

The username and password are both `vagrant`.

The V3SPA backend should now be running and accessible from your host machine at http://localhost:8080

You can run `vagrant suspend` to stop running the VM and `vagrant resume` to start it up again.

If you need to restart the services for some reason (e.g. you ran `vagrant up` but you cannot access V3SPA at http://localhost:8080) then log in to the VM using `vagrant ssh` and run these commands:

    $ cd /vagrant
    $ source vespa/bin/activate
    $ cd /home/vagrant/vespa
    $ mongod --dbpath ./mongodb &
    $ python /vagrant/vespa.py &
    $ (cd tmp/bulk && /home/vagrant/vespa/lobster/v3spa-server) &
    $ logout


### Docker Installation
There are Docker and docker-compose files along with some additional resources that allow you to run the application with Docker.

When running, it starts mongodb instance and connects the application to it.

In order to use it, you will need to install these requirements:

- Docker
- docker-compose

Then to run the application use these commands:

    $ docker-compose build
    $ docker-compose up

Following that, open a web browser and go to http://<docker-host>:8080/ (running on local machine, use http://localhost:8080/)

By default, the application will be served on port 8080. You can change the mapping in docker-compose.yml, line 7. For example to run it on port 7079 change it to `- 7079:8080`.

MongoDB is mounted on local folders in current directory. If required, you can change the mounting points in docker-compose.yml lines 21 and 26.


### Using V3SPA

Open your Chrome browser and go to http://localhost:8080 to load V3SPA.

The policy-examples directory contains several example policies in the format
required by V3SPA. If your policy is named "mypolicy", your zip file should be
named `mypolicy.zip` and all your policy files should be inside a directory
named `mypolicy` in the `mypolicy.zip` file. If you have a policy binary, the
file must be named `sepolicy` and it must be located in the `mypolicy/policy/`
directory in the zip, like this:

    mypolicy.zip
    │
    └───mypolicy
        │
        └───policy
            │   sepolicy

If you have policy source, it must be in reference policy
format, and the files and subdirectories should be in the `mypolicy` directory,
like this:

    mypolicy.zip
    │
    └───mypolicy
    │   │   build.conf
    │   │   Makefile
    │   │   rules.modular
    │   │   rules.monolithic
    │   │   ...
    │   │
    │   └───config
    │   │    │   ...
    │   │
    │   └───doc
    │   │    │   ...
    │   │
    │   └───man
    │   │    │   ...
    │   │
    │   └───policy
    │       │   ...
    │   
    └───support
        │   ...

Your zip file can contain only a binary, or only policy source, or both, as
long as your zip follows this structure and naming convention. If your zip file
has both a binary policy and source policy, simply add the `sepolicy` file to
the `mypolicy/policy/` in your policy source tree (in other words, merge the
two examples above).

Click the "Load" link and drag and drop one of the policies into V3SPA. Loading
a policy for the first time could take a minute or two to parse the policy.
Reloading a policy again later will be faster, but can still take a few seconds.
