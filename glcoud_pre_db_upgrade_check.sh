#!/bin/bash
#set -x
##-------------------------------------------------------------------------------------------------------------##
##   Name:        glcoud_pre_db_upgrade_check.sh
##   Purpose:     Pre-check a GCP instance for any possible issues before upgrading the database
##
##   Author:      Matt Pearson
##   Version:     Date                          Changes
##
##   1.0          17th Nov 2024                 Original
##   1.1          21st Nov 2024                 Added in the DB loop
##
##   Notes:
##   This script currently checks and reports on:
##
##    - LC_COLLATE - has to be en_US.UTF8
##    - Deprecated parameters - vacuum_defer_cleanup_age flag, force_parallel_mode
##    - Large Object metadata
##    - Issues with extensions - PostGIS, pgRouting & pg_squeeze
##
##      pg_squeeze and pgRouting are not supported in PG16 and higher versions in GCP.
##-------------------------------------------------------------------------------------------------------------##

## Global & Postgres variables

## Set the local PATH for the script (in case it goes into crontab)

export PATH=/bin:/usr/bin:/usr/sbin:/sbin:$PATH
export SCRIPT_NAME=$( basename $0 )
export SCRIPT_PREFIX=$( echo "${SCRIPT_NAME}" | awk -F. '{ print $1 }' )
export HOSTNAME=$( hostname -s )
export VERSION_NO="1.1"

## Files

export PGSQL_ERROR_FILE=/tmp/${SCRIPT_PREFIX}.pgsql_err.$$
export VERSION_OUTPUT=/tmp/${SCRIPT_PREFIX}.version
export SQL_TEMP_FILE=/tmp/${SCRIPT_PREFIX}.tmp.$$
export OUTPUT_FILE=/tmp/${SCRIPT_PREFIX}.out.$$
export DB_FILE_LIST=/tmp/${SCRIPT_PREFIX}.db.lst
export DB_EXT_FILE=/tmp/${SCRIPT_PREFIX}.ext.lst
export DB_META_OBJ=/tmp/${SCRIPT_PREFIX}.obj.lst

export DEPRECATED_PARAMETERS="('vacuum_defer_cleanup_age flag','force_parallel_mode')"

## Functions

function fnUsage        ## Function for the Usage to run the script from the command line
{

[ $VERBOSE ] && echo -e "$0"

cat << EOF

Usage: $0 -h [PG HOST] -d [PG database name] -u [PG username] -P [PG port number]

        -h      PG Database Cluster Host (or IP addr)
        -d      PG database (if a given database is required).  Default db is "postgres"
        -u      PG Role (to login with)
        -P      PG PORT (port number for the database cluster to connect to)
        -v      Verbose
        -V      VERSION
        -E      Show Environmental variables

        Example: $0 -h gcp-db-test-db01 -d postgres -u pg_admin -P 5432

        Note:   The PASSWORD is set via the environment variable PGPASSWORD or via adding it into the .pgpass file
                This to stop the password being visible in the process list.

EOF

exit $STATE_UNKNOWN

}

## PSQL error check

function psql_err_check
{
    [ $VERBOSE ] && echo -e "PSQL error check routine being run.\n"

    if [[ -f ${PGSQL_ERROR_FILE} && -s ${PGSQL_ERROR_FILE} ]]; then
        echo -e "Error with the SQL:\n$SQL_STMT\n: SQL Error: $( cat $PGSQL_ERROR_FILE )"
        rm -f $PGSQL_ERROR_FILE
        exit $STATE_UNKNOWN
    else
        [ $VERBOSE ] && echo -e "SQL query: $SQL_STMT"
    fi

}

function fnCleanup
{
        [[ -f ${PGSQL_ERROR_FILE}  ]]  && rm -f ${PGSQL_ERROR_FILE}
        [[ -f ${VERSION_OUTPUT} ]]     && rm -f ${VERSION_OUTPUT}
        [[ -f ${SQL_TEMP_FILE} ]]      && rm -f ${SQL_TEMP_FILE}
        [[ -f ${OUTPUT_FILE} ]]        && rm -f ${OUTPUT_FILE}
        [[ -f ${DB_FILE_LIST} ]]       && rm -f ${DB_FILE_LIST}
        [[ -f ${DB_EXT_FILE} ]]        && rm -f ${DB_EXT_FILE}
        [[ -f ${DB_META_OBJ} ]]        && rm -f ${DB_META_OBJ}

}

## Main

## Input parameters

## Get the INPUT from command line

while getopts h:d:u:P:vVE OPTIONS 2>/dev/null
do
        case "$OPTIONS" in
                h)      PG_HOST=$OPTARG ;;
                d)      PG_DB=$OPTARG ;;
                u)      PG_ROLE=$OPTARG ;;
                P)      PG_PORT=$OPTARG ;;
                v)      VERBOSE=1 ;;                 ## VERBOSE option
                V)      VERSION=1;;                  ## VERSION
                E)      SHOW_ENV=1 ;;
                ?)      echo -e "Unknown option used on the command line."
                        fnUsage;;
        esac
done

## PSQL connection parameters

if [[ ${VERSION} -eq 1 ]]; then
        echo -e "Script name: $0"
        echo -e "Version: $VERSION_NO"
        exit
fi


if [[ -z ${PG_HOST} ]]; then
        echo -e "Option -h [PG HOST] was left blank.  The server name or IP address needs to be provided."
        fnUsage
fi

if [[ -z ${PG_DB}} ]]; then
        PG_DB=postgres
        [ $VERBOSE ] && echo -e "Option -d [PG DB] was left blank."
fi

if [[ -z ${PG_ROLE} ]]; then
        echo -e "Option -u [PG ROLE] was left blank.  A valid username/role must be provided."
        fnUsage
fi

## If the port is blank, then assume the default port number

if [[ -z ${PG_PORT} ]]; then
        export PG_PORT=5432
fi

## Check the connectivity

## Check psql can be found

PSQL_CHECK=$( whereis psql | awk -F: '{ print $2 }' )

if [[ ! -n ${PSQL_CHECK} ]]; then
    echo -e "Unable to locate the psql binary in the PATH environmental variable.  PATH: $PATH"
    fnUsage
fi

SQL_CONNECT=" -h $PG_HOST -d ${PG_DB} -U ${PG_ROLE} -p ${PG_PORT} "

[ $VERBOSE ] && echo -e "Connection details: ${SQL_CONNECT}"

## Check the connection string

SQL_STMT="SELECT version();"

psql ${SQL_CONNECT} -c "${SQL_STMT}" -t 2>$PGSQL_ERROR_FILE > $VERSION_OUTPUT

[ $VERBOSE ] && echo -e "\nCommand line SQL Check: psql $SQL_CONNECT -c \"${SQL_STMT}\"\n\n"

[ $VERBOSE ] && echo -e "SQL query check results: $( cat $VERSION_OUTPUT )"

psql_err_check ${SQL_STMT}

## Check for deprecated parameters

SQL_STMT="SELECT name, setting, short_desc
          FROM    pg_settings
          WHERE   name IN ${DEPRECATED_PARAMETERS}
          ORDER BY 1;"

psql ${SQL_CONNECT} -c "${SQL_STMT}" -t 2>$PGSQL_ERROR_FILE > $SQL_TEMP_FILE

psql_err_check ${SQL_STMT}

if [[ $( cat $SQL_TEMP_FILE | grep -v ^$ | wc -l ) -gt 0 ]]; then
        echo -e "Deprecated parameters found on instance: $PG_HOST.\nInformation: $( cat $SQL_TEMP_FILE )\n"
else
        echo -e "No deprecated parameters found on instance: $PG_HOST.\n"
fi

## Check for LC_COLLATE

SQL_STMT="
SELECT  d.datname as dbname,
        pg_catalog.pg_get_userbyid(d.datdba) as dbowner,
        pg_catalog.pg_encoding_to_char(d.encoding) as encoding,
        CASE d.datlocprovider WHEN 'c' THEN 'libc' WHEN 'i' THEN 'icu' END AS locale_provider,
        d.datcollate as collate,
        d.datctype as ctype
FROM    pg_catalog.pg_database d
JOIN    pg_catalog.pg_tablespace t on d.dattablespace = t.oid
ORDER BY 1;"

psql ${SQL_CONNECT} -c "${SQL_STMT}" -P "footer=off" 2>$PGSQL_ERROR_FILE > $SQL_TEMP_FILE

psql_err_check ${SQL_STMT}

echo -e "LC Collate Check:\n$( cat $SQL_TEMP_FILE )\n"

## Check for issues in each catalog

SQL_STMT="SELECT  datname
          FROM    pg_stat_database
          WHERE   datname NOT IN ('template0', 'template1')
          ORDER BY 1;"

[ $VERBOSE ] && echo -e "SQL db list statement: ${SQL_STMT}"

psql ${SQL_CONNECT} -c "${SQL_STMT}" -t 2>$PGSQL_ERROR_FILE > ${DB_FILE_LIST}

psql_err_check ${SQL_STMT}

[ $VERBOSE ] && echo -e "DB List:\n\n$( cat $DB_FILE_LIST )"

for DB in $( cat $DB_FILE_LIST )
do
        #echo -e "DB: $DB"

        ## Change the Connection String

        SQL_CONNECT=" -h $PG_HOST -d ${DB} -U ${PG_ROLE} -p ${PG_PORT} "

        ## Check on extensions

        SQL_STMT="SELECT  *
                  FROM    pg_available_extensions
                  WHERE   upper(name) LIKE '%POSTGIS%'
                  OR      upper(name) IN ('pgRouting', 'pg_squeeze');"

        psql ${SQL_CONNECT} -c "${SQL_STMT}" -t 2>$PGSQL_ERROR_FILE > ${DB_EXT_FILE}

        psql_err_check ${SQL_STMT}

        if [[ $( cat ${DB_EXT_FILE} | grep -v ^$ | wc -l ) -gt 0 ]]; then

                echo -e "Problem extensions found in DB: $DB\n$( cat ${DB_EXT_FILE} )\n"
        else
                echo -e "No extensions have issues in DB: $DB\n"
        fi

        ## Check on large Metaobjects

        SQL_STMT="SELECT  *
                  FROM    pg_largeobject_metadata
                  ORDER BY 1;"

        psql ${SQL_CONNECT} -c "${SQL_STMT}" -t 2>$PGSQL_ERROR_FILE > ${DB_META_OBJ}

        psql_err_check ${SQL_STMT}

        if [[ $( cat ${DB_META_OBJ} | grep -v ^$ | wc -l ) -gt 0 ]]; then

                echo -e "Large Object data found in DB: $DB\n$( cat ${DB_META_OBJ} )\n"
        else
                echo -e "No Large Object data found in DB: $DB\n"
        fi

done

fnCleanup
