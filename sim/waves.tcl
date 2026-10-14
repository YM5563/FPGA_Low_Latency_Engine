database -open waves -shm -default
probe -create tb_sync_fifo -all -depth all
run
exit