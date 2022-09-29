#!/usr/bin/bash
set -x

Fsize="100" ## Must be in Gigibytes"
FIO="/usr/bin/fio"
FSNAME="pavfs"
FS_PATH="/gpfs/$FSNAME"
M="$FS_PATH/data"
RESULTS="/root/results/$FSNAME"
TIME="120"
RUNTIME="--runtime=$TIME"  # ""<-
W="Pav_32Node_32files"
CFILE="/tmp/exnode.cfg"
mmgetstate -a | grep -i "active" | awk '{print $2}' > $CFILE
CLIENTS=`cat $CFILE`

DIRIO="1"
NJOBS="64"
IOD="32"


READ_PCT=80

if [ ! -d $M ]
then
    mkdir -p $M
fi

pssh -i -h $CFILE -t 0 "mkdir -p $RESULTS"

for NODE in $CLIENTS
do
    if [ ! -d $M/$NODE ]
    then
         mkdir -p $M/$NODE
    else
         ssh $NODE "rm -f $M/$NODE/*"
    fi
done

function create_result_files () {    #$1=$TT $2=$RESULTS $3=$FILESTRING
    echo "$1 $2 $3"
    for NODE in $CLIENTS
    do
        ssh $NODE "echo IOPS iops Start of $1 > ${2}/${NODE}${3}.out"
        ssh $NODE "echo IOPS iops Start of $1 > ${2}/${NODE}${3}_IOSTAT.out"
        ssh $NODE "iostat -xzm 10 > ${2}/${NODE}${3}_IOSTAT.out &"
    done
}

function create_perf_files () {    #$1=$TT  $2=$X $3=$RESULTS $4=$FILESTRING
    echo "$1 $2 $3 $4"
    for NODE in $CLIENTS
    do
        ssh $NODE "echo iopsIOPS Start of Run $1 blocksize $2 >> ${3}/${NODE}${4}.out"
        ssh $NODE "echo iopsIOPS Start of Run $1 blocksize $2 >> ${3}/${NODE}${4}_IOSTAT.out"
    done

}

################################
#  All Test Loops
#for TT in "write" "randread" "read"  "rewrite" "readwrite --rwmixread=$READ_PCT"
for TT in "randwrite" "randread"
do
   RW=`echo $TT | awk '{ print $1 }'`
   FILESTRING="_${W}_${RW}_QD${IOD}_DIO${DIRIO}_${NJOBS}files_sz${Fsize}_`date +%m%d%H%M`"

   if [ "$TT" == "write" ]
   then
      CREATE=" --create_on_open=1 --fallocate=0 "
   else
      CREATE=""
   fi

   echo "Creating Output Files $TT And Stating iostat - 3 pssh"
   if [ "$TT" == "readwrite --rwmixread=$READ_PCT" ]
   then
       create_result_files "readwrite_rwmixread_$READ_PCT" $RESULTS $FILESTRING
   else
       create_result_files $TT $RESULTS $FILESTRING
   fi

   #for X in 8192k 4096k 1024k 256k 64k 32k 4k
   for X in 256k 64k 32k 4k
   do
      if [ "$X" == "8192k" ] && [ "$TT" == "write" ]
      then
         RUNTIME=""
      else
         RUNTIME="--runtime=$TIME"
      fi
 
      echo "Updating Output Files $X - 2 pssh"
      if [ "$TT" == "readwrite --rwmixread=$READ_PCT" ]
      then
         create_perf_files "readwrite_rwmixread_$READ_PCT"  ${X} ${RESULTS} ${FILESTRING}
      else
         create_perf_files ${TT} ${X} ${RESULTS} ${FILESTRING}
      fi

      echo "Starting fio $TT $X" 

      if [ "$TT" == "rewrite" ]
      then
         TYPE="write"
      else
         TYPE="$TT"
      fi

      for I in $CLIENTS
      do
  	 COMMAND="fio --direct=${DIRIO} --rw=$TYPE  --thread --iodepth=${IOD} --numjobs=${NJOBS} --ioengine=libaio --bs=$X --group_reporting=1 --size=${Fsize}G $CREATE --end_fsync=1 $RUNTIME --name=i${I} --directory=${M}/$I >> ${RESULTS}/${I}${FILESTRING}.out"
  	 #COMMAND="fio --direct=${DIRIO} --rw=$TYPE  --thread --iodepth=${IOD} --numjobs=${NJOBS} --ioengine=libaio --bs=$X --group_reporting=1 --size=${Fsize}G $CREATE --end_fsync=1 $RUNTIME --name="'`hostname -s`'" --directory=${M}/$I >> ${RESULTS}/"'`hostname -s`'"${FILESTRING}.out"
  	 ssh $I "$COMMAND" &
      done

###################################################
# Verify FIO Finishes

      echo "fio finished: Verify Done on all"

      STOPPED="5"
      echo "waiting for FIO to end"
      for C in $CLIENTS
      do
         echo $C $X $TT 
         while [ "$STOPPED" != "1" ]
         do
            TEST=`ssh $C "ps -ef | grep numjobs | grep -v grep | wc -l"`
            if [ "$TEST" != "0" ]
            then
               echo $C $X $TT	
	       sleep 20
            else
               STOPPED=1
            fi
         done

         STOPPED="0"
      done
      echo "FIO finished"

#####################################################
#  Deleting Files

      if [ "$X" != "8192k" ] && [ "$TT" == "write" ]
      then
         echo "Deleting Files"
         date

         SIZE=`df -k | grep pav | awk '{ print $3 }'`

         #pssh -i -h $CFILE -t 0 "rm -f ${M}/"'`hostname -s`'"/*"
         #pssh -i -h $CFILE -t 0 "rm -f ${M}1/"'`hostname -s`'"/*"

         STOPPED="5"
         sleep 30

         while [ "$STOPPED" != "1" ]
         do
            TEST=`df -k --sync | grep pav | awk '{ print $3 }'`
            if [ "$TEST" != "$SIZE" ]
            then
               echo "Sleeping 30 $SIZE $TEST"
               SIZE="$TEST"
               sleep 30
            else
               STOPPED=1
               echo "End Delete $TEST $SIZE"
            fi
         done
      fi
######################################################################
# Clear Cache

      pssh -i -h $CFILE -t 0 "sync; echo 3 > /proc/sys/vm/drop_caches"

   done  #####  End of Block Size Loop
    
   echo "Killing iostat for $TT - 2 pssh"
   pssh -i -h $CFILE -t 0 "killall iostat"
   pssh -i -h $CFILE -t 0 "killall iostat"
       
done  #####  End of Test Type TT  Loop


