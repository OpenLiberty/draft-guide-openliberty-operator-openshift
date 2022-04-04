#!/bin/bash
set -euxo pipefail

cd system

# Build the system/ app
mvn -Dhttp.keepAlive=false \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 \
    -q clean package liberty:create liberty:install-feature liberty:deploy

# Verifies that the system app is functional
mvn liberty:start
if curl "http://localhost:9080/health" | grep "UP" ; then exit $?; fi
if curl "http://localhost:9080/system/properties" | grep "os.name" ; then exit $?; fi
mvn liberty:stop

# Delete m2 cache after completion
rm -rf ~/.m2
