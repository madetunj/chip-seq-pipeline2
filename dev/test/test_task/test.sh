#!/bin/bash
set -e # exit on error

if [ $# -lt 2 ]; then
  echo "Usage: ./test.sh [WDL] [INPUT_JSON] [DOCKER_IMAGE](optional)"
  echo "Make sure to have cromwell-31.jar in your \$PATH as an executable (chmod +x)."
  exit 1
fi

WDL=$1
INPUT=$2
if [ $# -gt 2 ]; then
  DOCKER_IMAGE=$3
else
  DOCKER_IMAGE="conda"
fi
if [ $# -gt 3 ]; then
  NUM_TASK=$4
else
  NUM_TASK=1
fi

if [ -f "cromwell-42.jar" ]; then
  echo "Skip downloading cromwell."
else
  wget -N -c https://storage.googleapis.com/encode-pipeline-test-samples/cromwell_jar/cromwell-42.jar
fi
CROMWELL_JAR=cromwell-42.jar
BACKEND_CONF=backend.conf
BACKEND=Local
EXTRA_PARAM="-Dbackend.providers.Local.config.concurrent-job-limit=2"
PREFIX=$(basename ${WDL} .wdl)
METADATA=${PREFIX}.metadata.json # metadata
RESULT=${PREFIX}.result.json # output

# Write workflow option JSON file
TMP_WF_OPT=$PREFIX.test_chip_wf_opt.json
cat > $TMP_WF_OPT << EOM
{
    "default_runtime_attributes" : {
        "docker" : "$DOCKER_IMAGE"
    }
}
EOM
if [ $DOCKER_IMAGE == 'conda' ]; then
  WF_OPT=
else
  WF_OPT="-o ${TMP_WF_OPT}"
fi
java -Dconfig.file=${BACKEND_CONF} -Dbackend.default=${BACKEND} ${EXTRA_PARAM} -jar ${CROMWELL_JAR} run ${WDL} -i ${INPUT} ${WF_OPT} -m ${METADATA}

# parse output metadata json
cat ${METADATA} | python -c "import json,sys;obj=json.load(sys.stdin);key='${PREFIX}.compare_md5sum.json_str';print(obj['outputs'][key] if key in obj['outputs'] else '')" > ${RESULT}
cat ${RESULT}
rm -f ${METADATA} ${TMP_WF_OPT}
