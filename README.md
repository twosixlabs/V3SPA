V3SPA
=================
## About

V3SPA is a tool for visualizing and analyzing SELinux and SEAndroid security policies.

To address the challenges in developing and maintaining SELinux security policies, we developed V3SPA (Verification, Validation and Visualization of Security Policy Abstractions). V3SPA creates an abstraction of the underlying security policy using the Lobster domain-specific language, and then tightly integrates exploratory controls and filters with visualizations of the policy to rapidly analyze the policy rules. V3SPA includes several novel analysis modes that change the way policy authors and auditors build and analyze SELinux policies. These modes include: 

1. A mode for differential policy analysis. This plugin shows analysts a visual diff of two versions of a security policy, allowing analysts to clearly see changes made. Using dynamic query filters, analysts can quickly answer questions such as, "What are the changes that affect passwd_t?" 

2. A mode for analyzing information flow, identifying unexpected sets of permissions, and examining the overall design of the policy. This plugin allows users to see the entire policy at once, filter down to see only the components of interest, and execute reachability queries both from and to specified domains.

## Requirements

The V3SPA backend has been tested on Fedora 24 and Chrome. V3SPA requires setools v4.

To setup the backend on a Fedora box:

    $ sudo dnf install -y python git setools-devel setools-libs bzip2-devel bison flex nodejs python-tornado python-devel mongodb-server swig libsepol libsepol-devel libsepol-static redhat-rpm-config
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

## Misc
At this point you should create the appropriate firewall rules for 
your machine to allow external access to port 8080 if you would like
the service open to other clients.

Otherwise, open your Chrome browser and go to http://localhost:8080 to load
V3SPA.

The policy-examples directory contains several example policies in the format
required by V3SPA. If you have a policy binary, the file must be named sepolicy
and it must be located in the policy/ directory. If you have source, it must be
in reference policy format. Your zip file can contain only a binary, or only
policy source, or both, as long as it follows this structure and naming
convention.