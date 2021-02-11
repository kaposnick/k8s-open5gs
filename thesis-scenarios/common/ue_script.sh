#!/bin/bash

E_BADARGS=85

if [ $# -ne 3 ]
then
    echo "Usage: $0 <num_enbs> <num_ues> <configuration_dir_path>"
    echo "Exiting..."
    exit ${E_BADARGS}
fi

NUM_OF_ENBS=$1
NUM_OF_UES=$2
DIR_CONFIG=$3

cd ${DIR_CONFIG}

if [ $NUM_OF_ENBS -le 0 ]
then
    echo "The number of eNBs should be higher than 0"
    echo "Exiting..."
    exit ${E_BADARGS}
fi

RANGE_START_PORTS_UE=30000
RANGE_START_PORTS_ENB=35000

LOG_ARGS="--log.all_level=info"

let "NUM_OF_UES_PER_ENB = ${NUM_OF_UES}/ ${NUM_OF_ENBS}"
let "REM_OF_UES = ${NUM_OF_UES} % ${NUM_OF_ENBS}"

for INDEX_ENB in {0..'expr ${NUM_OF_ENBS} - 1'}
do
    let ENB_UES=${NUM_OF_UES_PER_ENB}
    if [ REM_OF_UES -gt 0 ]
    then
        let ENB_UES+=1
        let REM_OF_UES-=1
    fi

    PORT_ARGS=""
    for INDEX_UE in {0..'expr ${ENB_UES} - 1'}
        if [ ${#PORT_ARGS} -gt 0 ]
        then
            PORT_ARGS=${PORT_ARGS},
        fi
        PORT_ARGS=${PORT_ARGS}tx_port${INDEX_UE}=tcp://*:${RANGE_START_PORTS_ENB},rx_port${INDEX_UE}=tcp://localhost:'expr $RANGE_START_PORTS_ENB + 1'
        let "RANGE_START_PORTS_ENB = ${RANGE_START_PORTS_ENB} + 2"
    do

    ZMQ_ARGS="--rf.device_name=zmq --rf.device_args=\"${PORT_ARGS},id=enb,base_srate=23.04e6\""
    OTHER_ARGS="--enb_files.rr_config=rr2.conf --enb.enb_id=$(printf "%x" ${INDEX_ENB}) --enb.gtp_bind_addr=127.0.1.'expr $INDEX_ENB + 1' --enb.s1c_bind_addr=127.0.1.'expr $INDEX_ENB + 1'"

    sudo srsenb enb.conf ${LOG_ARGS} ${ZMQ_ARGS} ${OTHER_ARGS} > log/enb_${INDEX_ENB} 2>$1 &
    done
done







