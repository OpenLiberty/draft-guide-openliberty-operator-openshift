oc delete -f deploy.yaml
oc delete imagestream.image.openshift.io/system-imagestream
oc delete bc system-buildconfig
sleep 10
oc get routes
oc get OpenLibertyApplications
oc get imagestreams
oc get all -l name=system
