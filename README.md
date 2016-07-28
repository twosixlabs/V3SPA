V3SPA Angularized
=================
## Requirements

- nodejs
- npm
- python
- pip
- mongodb
- setools v4

The V3SPA backend has been tested on Fedora 23 and 24.

To set up the environment:

    $ sudo dnf install gcc nodejs npm python-tornado python-pip git python-devel mongodb-server
    $ sudo pip install virtualenv
    $ mkdir vespa && cd vespa
    $ git init
    $ git clone http://gitlab.labs/v3spa/ide.git
    $ cd ide
    $ git submodule update --init
    $ sudo npm install -g gulp
    $ sudo npm install
    $ virtualenv vespa
    $ source vespa/bin/activate
    $ pip install -r requirements.txt

To run sesearch you will need SETools v4, e.g. [https://github.com/TresysTechnology/setools/releases/tag/4.0.1] and follow the [build instructions](https://github.com/TresysTechnology/setools/blob/06ee08141a23b3d88e5f6fc4f53e9654f36611d5/README.md)

## Building

All of the assets are served from static/, but they aren't
actually stored there. The Gulp build system is responsible for
compiling assets and putting them in the right place.

## Layout

All of the client side code is located in src/. All external
libraries are in external/.

## Database

Mongo is installed at this point, but you need to create a location
for database storage. Then launch Mongod.
(Assuming you are in vespa directory.)

    $ mkdir ./mongodb

## Running

Mongo and two more binaries need to be launched.
(Assuming you are in the vespa dirrectory.)

    $ mongod --dbpath ./mongodb &
    $ python ide/vespa.py &
    $ (cd tmp/bulk && ../../api/bin/lobster-server) &

## Misc
At this point you should create the appropriate firewall rules for 
your machine to allow external access to port 8080 if you would like
the service open to other clients.

## Automated Install

There is a vagrant file and shell script provided to execute all the steps
during provisioning without launching Mongo or the two binaries at the end.