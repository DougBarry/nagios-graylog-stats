#!/bin/bash
# Doug Barry at University of Greenwich 20180123

PERMITTED_STAT_FUNCTIONS=( append_events_per_second read_events_per_second uncommitted_journal_entries journal_size journal_size_limit oldest_segment journal_percent )

usage() {
	echo -e "Usage: $0 [-t <api base url>] [-u <api username>] [-q <api password>] [-f <stat function> [-w <warning level>] [-c <critical level>]\nAll arguments must be supplied.\nStat functions:" 1>&2
	for i in "${PERMITTED_STAT_FUNCTIONS[@]}"
	do
		echo -e "\t${i}" 1>&2
	done
	exit 4
}

while getopts ":t:u:q:f:w:c:" arg; do
	case "${arg}" in
		t)
			API_BASE_URL=${OPTARG}
			;;
		u)
			API_USER=${OPTARG}
			;;
		q)
			API_PASSWORD=${OPTARG}
			;;
		w)
			WARNING_LEVEL=${OPTARG}
			;;
		c)
			CRITICAL_LEVEL=${OPTARG}
			;;
		f)
			API_GREP=${OPTARG}
			;;
		*)
			usage
			;;
	esac
done

if [ -z ${API_BASE_URL+x} ] || [ -z ${API_USER+x} ] || [ -z ${API_PASSWORD+x} ] || [ -z ${WARNING_LEVEL+x} ] || [ -z ${CRITICAL_LEVEL+x} ] || [ -z ${API_GREP+x} ]
then
	usage
fi

for i in "${PERMITTED_STAT_FUNCTIONS[@]}"
do
    if [ "$i" == "${API_GREP}" ]; then
        API_GREP_OK="1"
    fi
done

if [ "${API_GREP_OK}" != "1" ]; then
	echo "Invalid Stat Function ${API_GREP}" 1>&2
	exit 4
fi

if [ $(awk 'BEGIN {print ("'${WARNING_LEVEL}'" >= "'${CRITICAL_LEVEL}'")}') == "1" ]; then
	echo "Critical level less than warning level" 1>&2
	exit 4
fi

if [ "${API_GREP}" == "journal_percent" ]; then
	RESULT_S=$(curl -k -i --silent -u ${API_USER}:${API_PASSWORD} -H 'Accept: application/json' -X GET "${API_BASE_URL}/system/journal?pretty=true" | grep \"journal_size\" | awk '{print $3}' | tr -d ',')

	RESULT_L=$(curl -k -i --silent -u ${API_USER}:${API_PASSWORD} -H 'Accept: application/json' -X GET "${API_BASE_URL}/system/journal?pretty=true" | grep \"journal_size_limit\" | awk '{print $3}' | tr -d ',')
	
	RESULT=$(awk "BEGIN { pc=100*${RESULT_S}/${RESULT_L}; printf \"%.2f\", pc }")
else
	RESULT=$(curl -k -i --silent -u ${API_USER}:${API_PASSWORD} -H 'Accept: application/json' -X GET "${API_BASE_URL}/system/journal?pretty=true" | grep \"${API_GREP}\" | awk '{print $3}' | tr -d ',')
fi

if [ -z "${RESULT+x}" ]; then
	echo "UNKNOWN"
	exit 3
fi

if [ $(awk 'BEGIN {print ('${RESULT}' >= '${WARNING_LEVEL}')}') == "1" ]; then
	echo "WARNING - ${RESULT}|size=${RESULT}"
	exit 1
fi
	
if [ $(awk 'BEGIN {print ('${RESULT}' >= '${CRITICAL_LEVEL}')}') == "1" ]; then
	echo "CRITICAL - ${RESULT}|size=${RESULT}"
	exit 2
fi

echo "OK - ${RESULT}|${API_GREP}=${RESULT}"