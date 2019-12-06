#!/bin/zsh

function do_insert {
    local table=$1 id=$2
    mysql -h$dbHost -u$dbUser -p$dbPassword a -e "insert into $table values($id, '$id-c')"
}

function verify {
    local table=$1 from=$2 end=$3
    local expect=$((end-from))
    echo -n "Verify [$table] [$from,$end) Expect: $expect ..."
    local cnt=$(mysql -h$dbHost -u$dbUser -p$dbPassword a \
                 -e "select count(1) from $table where id >=$2 and id <$3" \
                 | sed -e 1d)
    if [ $cnt -ne $expect ]
    then
        echo " ERROR ! count=$cnt "
        exit 1
    fi
    echo " Pass !"
}

function do_insert_batch {
    local table=$1 start=$2 step=$3 batch=$4
    for i in {1..$batch}
    do
        do_insert $table $((i*step+start))
    done
}

function fork_one {
    local index=$1
    shift
    local table=$1 start=$2 step=$3 count=$4
    mkdir -p log/$table/
    local log=log/$table/$index.log
    echo "==New-Thread===" >>$log
    do_insert_batch $table $start $step $count &>>$log &
    local child_pid=$!
    eval pid_$index=$child_pid
    echo "[$table.$index] forked child : $child_pid for [$start $step $count]"
}

function do_concurrent_insert {
    local table=$1 concurrency=$2 start=$3 batch=$4
    for i in {1..$concurrency}
    do
        fork_one $i $table $start $concurrency $batch
    done
    ## wait all thead done
    for i in {1..$concurrency}
    do
        eval pidx=\$pid_$i
        wait $pidx
        echo "[$i] child : $pidx completed."
    done
    echo "All child completed."
    echo "Verify Inserts ..."
    verify $table $start $((start + concurrency*batch))
}

function single_table_cc {
    if [ $# -ne 3 ]
    then
        echo "$0 table concurrency stugger(s)"
        exit 1
    fi
    local table=$1 concurrency=$2 stugger=$3 i=0
    while :
    do
        echo "start concurrent insert : i=$i, table=$table"
        do_concurrent_insert $table $concurrency $i 10000
        i=$((i+10000*concurrency))
        sleep $stugger
    done
}

export dbUser=
export dbPassword=
export dbHost=

if [ -z $dbUser -o -z $dbPassowrd -o -z $dbHost ]
then
    echo "please setup dbUser dbPassword dbHost"
    exit 1
fi

single_table_cc hello1 20 300 &>hello1.20.300.log &

single_table_cc hello2 20 500 &>hello2.20.500.log &

single_table_cc hello3 20 600 &>hello3.20.600.log &

single_table_cc hello4 100 700 &>hello4.100.700.log &

single_table_cc hello5 100 700 &>hello5.100.900.log &
