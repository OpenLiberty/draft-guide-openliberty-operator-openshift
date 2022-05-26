#!/bin/bash
set -euxo pipefail

cp -r /home/project/guide-openliberty-operator-openshift/finish/* \
    /home/project/guide-openliberty-operator-openshift/start
cd /home/project/guide-openliberty-operator-openshift/start

oc projects
oc api-resources --api-group=apps.openliberty.io
mvn clean package
oc process -f build.yaml | oc create -f -
oc get all -l name=system

oc start-build system-buildconfig --from-dir=system/.
oc get builds
oc get imagestreams
oc describe imagestream/system-imagestream

while :
do
    if [ "$(oc logs build/system-buildconfig-1 | grep successful)" ];
    then
        echo Build Complete
        break
    fi
    sleep 15
done

sleep 60

sed -i 's=guide/system-imagestream:1.0-SNAPSHOT='"$SN_ICR_NAMESPACE"'/system-imagestream:1.0-SNAPSHOT\n  pullPolicy: Always\n  pullSecret: icr=g' deploy.yaml
oc apply -f deploy.yaml

oc get OpenLibertyApplications
oc describe olapps/system

sleep 15

oc get pods

curl -I http://"$(oc get routes system -o jsonpath='{.spec.host}')/system/properties" | grep "200 OK" || exit 1

oc delete -f deploy.yaml
oc delete imagestream.image.openshift.io/system-imagestream
oc delete bc system-buildconfig
