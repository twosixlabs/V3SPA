(cd /vespa/tmp/bulk && ../../V3SPA/lobster/v3spa-server/dist/bin/v3spa-server) &

cd /vespa
sh /wait-for-it.sh mongo1:27017 -- python V3SPA/vespa.py
