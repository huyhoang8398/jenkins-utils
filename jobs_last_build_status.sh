#!/bin/bash

function isEmptyString()
{
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function removeEmptyLines()
{
    local -r content="${1}"

    echo -e "${content}" | sed '/^\s*$/d'
}

function trimString()
{
    local -r string="${1}"

    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

function repeatString()
{
    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "$(isPositiveInteger "${numberToRepeat}")" = 'true' ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isPositiveInteger()
{
    local -r string="${1}"

    if [[ "${string}" =~ ^[1-9][0-9]*$ ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function printTable()
{
    local -r delimiter="${1}"
    local -r tableData="$(removeEmptyLines "${2}")"
    local -r colorHeader="${3}"
    local -r displayTotalCount="${4}"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${tableData}")" = 'false' ]]
    then
        local -r numberOfLines="$(trimString "$(wc -l <<< "${tableData}")")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${tableData}")"

                local numberOfColumns=0
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                # Add Header Or Body

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#|  %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                local output=''
                output="$(echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1')"

                if [[ "${colorHeader}" = 'true' ]]
                then
                    echo -e "\033[1;32m$(head -n 3 <<< "${output}")\033[0m"
                    tail -n +4 <<< "${output}"
                else
                    echo "${output}"
                fi
            fi
        fi

        if [[ "${displayTotalCount}" = 'true' && "${numberOfLines}" -ge '0' ]]
        then
            echo -e "\n\033[1;36mTOTAL ROWS : $((numberOfLines - 1))\033[0m"
        fi
    fi
}

echo "Job, Commit, Commit Revision, Status"> jenkins_data.txt

# Array: list of jobs name
JOB_NAME=()

USERNAME=''
PASSWORD=''

for job in ${JOB_NAME[@]}; do
    JOB_URL=''
    
    # Get previous run status, returns like: result":"UNSTABLE
    # buildInfo=$(curl --user ${USERNAME}:${PASSWORD} -silent ${JOB_URL}/lastBuild/api/json \
                  # | grep -iEo 'result":"\w*|fullDisplayName":"[^\,]*|comment":"[^\,]*')

    buildInfo=$(curl --user ${USERNAME}:${PASSWORD} -silent ${JOB_URL}/lastBuild/api/json \
                  | grep -iEo 'result":"\w*|fullDisplayName":"[^\,]*|lastBuiltRevision":{"SHA1":"([A-Z 0-9])\w+')
    
    # Strip out leading identifier, i.e: result":"
    buildRev=$(echo ${buildInfo} | awk '{print $1}' | sed 's/lastBuiltRevision\"\:{\"SHA1\"\:\"//' | head -c 7)

    buildFullDisplayName=$(echo ${buildInfo} | awk '{print $2, $3, $4, $5, $6}' | sed 's/fullDisplayName\"\:\"//') 

    buildStatus=$(echo ${buildInfo} | awk '{print $8}' | sed 's/result\"\:\"//')
    
    ### Optional ###
    # buildCommit=$(echo ${buildInfo} | awk '{print $7}' | sed 's/\"//' | sed 's/\#//')
    # buildChange=$(echo ${buildInfo} | awk '{print ""}{for(i=8;i<=NF;++i)printf $i" "}' | sed 's/comment\"\:\"/\n/g')

    echo -e ${job} "," ${buildFullDisplayName} "," ${buildRev} "," ${buildStatus} >> jenkins_data.txt
done

printTable ',' "$(cat jenkins_data.txt)"
