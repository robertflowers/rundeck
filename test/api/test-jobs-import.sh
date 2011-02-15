#!/bin/bash

#test /api/jobs/import

DIR=$(cd `dirname $0` && pwd)
source $DIR/include.sh

args="echo hello there"

project=$2
if [ "" == "$2" ] ; then
    project="test"
fi

#escape the string for xml
xmlargs=$($XMLSTARLET esc "$args")
xmlproj=$($XMLSTARLET esc "$project")

#produce job.xml content corresponding to the dispatch request
cat > $DIR/temp.out <<END
<joblist>
   <job>
      <name>cli job</name>
      <group>api-test</group>
      <description></description>
      <loglevel>INFO</loglevel>
      <context>
          <project>$xmlproj</project>
      </context>
      <dispatch>
        <threadcount>1</threadcount>
        <keepgoing>true</keepgoing>
      </dispatch>
      <sequence>
        <command>
        <exec>$xmlargs</exec>
        </command>
      </sequence>
   </job>
</joblist>

END

# now submit req
runurl="${APIURL}/jobs/import"

echo "TEST: import RunDeck Jobs in jobs.xml format"

params=""

# specify the file for upload with curl, named "xmlBatch"
ulopts="-F xmlBatch=@$DIR/temp.out"

# get listing
$CURL $ulopts --header "$VERSHEADER" ${runurl}?${params} > $DIR/curl.out
if [ 0 != $? ] ; then
    errorMsg "ERROR: failed query request"
    exit 2
fi

sh $DIR/api-test-success.sh $DIR/curl.out || exit 2

#result will contain list of failed and succeeded jobs, in this
#case there should only be 1 failed or 1 succeeded since we submit only 1

failedcount=$($XMLSTARLET sel -T -t -v "/result/failed/@count" $DIR/curl.out)
succount=$($XMLSTARLET sel -T -t -v "/result/succeeded/@count" $DIR/curl.out)
skipcount=$($XMLSTARLET sel -T -t -v "/result/skipped/@count" $DIR/curl.out)

if [ "1" != "$succount" ] ; then
    errorMsg  "Upload was not successful."
    exit 2
fi

# verify results
jid=$($XMLSTARLET sel -T -t -v "/result/succeeded/job/id" $DIR/curl.out)
jname=$($XMLSTARLET sel -T -t -v "/result/succeeded/job/name" $DIR/curl.out)
jgroup=$($XMLSTARLET sel -T -t -v "/result/succeeded/job/group" $DIR/curl.out)
jproj=$($XMLSTARLET sel -T -t -v "/result/succeeded/job/project" $DIR/curl.out)

assert "cli job" "$jname" "Wrong job name: $jname"
assert "api-test" "$jgroup" "Wrong job group: $jgroup"
assert "$project" "$jproj" "Wrong job project: $jproj"

if [ -z "$jid" ] ; then
    errorMsg "Expected job id in result: $jid"
    exit 2
fi

echo "OK"

rm $DIR/curl.out
rm $DIR/temp.out