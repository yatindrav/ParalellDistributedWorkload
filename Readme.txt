The fio workload descriptions are as under:
    a. random read and write and sequential read and write 
    b. block sizes:“8192k 4096k 2048k 1024k 256k 128k 64k 32k 16k 8k 4k" (this can be changed as per the workload)
       direct IO
    c. 64 fio jobs (this can be changed)
    d. 32 IO Queue depth (this can be changed)
    e. Each workload will go for 3mins and total test time will vary on what the block sizes are selected for test.
    f. Create file /tmp/exnode.cfg with nodes name in it on which test will be run
    g. fio executable path has to be updated in the script variable $FIO

Following are the expectations and assumption in the script:
    a. This script has to fired from manager nodes
    b. Distributed filesystem cluster is having only active nodes then no need to change anything in test participating node perspective
    c. All nodes are enabled with password less access
    d. PSSH is installed on the manager node to run command in parallel on active nodes in Distributed filesystem cluster
    e. The file system name as I know is pav need to change if it is changed. The script variable to update is $FSNAME
    f. Install fio on all the nodes
