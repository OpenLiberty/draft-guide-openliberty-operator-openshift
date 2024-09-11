#!/bin/bash
set -euxo pipefail

delete_oc () {
    oc delete -f deploy.yaml
    oc delete imagestream.image.openshift.io/system-imagestream
    oc delete bc system-buildconfig
}

oc projects | grep "You have one project" || exit 1
oc api-resources --api-group=apps.openliberty.io | grep openlibertyapplications | grep true || exit 1
oc api-resources --api-group=apps.openliberty.io | grep openlibertydumps | grep true || exit 1
oc api-resources --api-group=apps.openliberty.io | grep openlibertytraces | grep true || exit 1

cd /home/project/guide-openliberty-operator-openshift/finish

sed -i 's=0.9=0.99=g' ./system/src/main/java/io/openliberty/guides/system/health/SystemLivenessCheck.java
sed -i 's=0.95=0.99=g' ./system/src/main/java/io/openliberty/guides/system/health/SystemStartupCheck.java
sed -i 's=60=6=g' ./system/src/main/java/io/openliberty/guides/system/health/SystemReadinessCheck.java

mvn clean package
oc process -f build.yaml | oc create -f - || exit 1
oc start-build system-buildconfig --from-dir=system/. || exit 1
sleep 40
oc get builds | grep Running || exit 1
sleep 200

time_out=0
while :
do
    if [ "$(oc logs build/system-buildconfig-1 | grep "Push successful")" = "Push successful" ];
    then
        echo Build Complete
        break
    fi

    time_out=$((time_out + 1))
    sleep 15

    if [ "$time_out" = "24" ]; 
    then
        echo Unable to build
        oc logs build/system-buildconfig-1
        oc delete imagestream.image.openshift.io/system-imagestream
        oc delete bc system-buildconfig
        exit 1
    fi
done

oc get imagestreams
oc describe imagestream/system-imagestream

sed -i 's=guide/system-imagestream:1.0-SNAPSHOT='"$SN_ICR_NAMESPACE"'/system-imagestream:1.0-SNAPSHOT\n  pullPolicy: Always\n  pullSecret: icr=g' deploy.yaml
oc apply -f deploy.yaml

has_event=$(oc describe olapps/system | grep "Event.*<none>" | cat); if [ "$has_event" = "" ]; then echo Unexpected event has occured; exit 1; fi

time_out=0
while :
do
    if [ ! "$(curl -kIs --connect-timeout 5 https://"$(oc get routes system -o jsonpath='{.spec.host}')/health" | grep "200 OK")" = "" ];
    then
        break
    fi
    
    time_out=$((time_out + 1))

    if [ "$time_out" = "24" ];
    then
        set +x pipefail
        echo Unable to reach /health endpoint
        oc get pods
        #echo Try rerunning the this test script
        # delete_oc
        echo
        echo Try to visit the following URLs manually on your browser:
        echo
        echo https://$(oc get routes system -o jsonpath='{.spec.host}')/health
        echo
        echo https://$(oc get routes system -o jsonpath='{.spec.host}')/system/properties
        echo
        echo Pass if both URLs work.
        echo Then, run ../scripts/tearDownSN.sh
        exit 1
    fi
done

curl -kIs https://"$(oc get routes system -o jsonpath='{.spec.host}')/system/properties" | grep "200 OK" || echo Failure deploying container | exit 1

delete_oc

echo Tests Passed!

