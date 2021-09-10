#!/bin/bash
version=2.1.0
# create by Woonjib Baik 2013/12/18
# kill & /u01 logging added in 1.5.2  
# extend mod added, 10g eth add in 1.5.3  
# X4 monitor add 1.5.4
# reporting funciton add 1.6.2
# X5 monitor add 1.7.0
# Solaris support 1.7.5
# Connection timeout 1.7.6
# X6 monitor add 1.9.0
# X7 monitor add 1.9.5
# X8M monitor add 2.0.1
# X-8 monitor, Color add 2.1.0
# last update at 2021/01/28

LANG=C

# Graph setting
X_AXIS_SIZE=160
Y_AXIS_SIZE=10
# color setting
CRI_COL="\033[1;31m"
WARN_COL="\033[1;32m"
RESET_COL="\033[00m"
CPU_CRI=80
CPU_WARN=40
IO_CRI=60
IO_WARN=40
ROCE_CRI=6000
ROCE_WARN=3000
PMEM_CRI=8000
PMEM_WARN=4000
MEM_CRI=80
MEM_WARN=60

i=1
t=`date +%H%M%S`
user_name=`id -un`
os_name=`uname`
prg_name=`echo $0|awk -F'/' '{print $(NF)}'`

log_f=0; dsk_f=0; top_f=0; mon_f=0; ib_f=0; run_f=0; ext_f=0; debug_f=0; ovm_f=0; readonly_f=0; pmem_f=0

if [ $# -le 1 ]; then
  if  [ "$1" == "-k" ]; then
    cnt=`ps -fle|grep $prg_name|grep -v grep|grep ^1|wc -l`
    if [ $cnt -eq 1 ]; then
      sleep 1
      cnt=`ps -fle|grep $prg_name|grep -v grep|grep ^1|wc -l`
      #echo 1: $cnt
      if [ $cnt -eq 1 ]; then
        echo $prg_name $psid is not running
        exit
      fi
    fi
    printf "$prg_name will be killed [Y/N] : "
    read flag_xx
    if [ "$flag_xx" == "Y" ] || [ "$flag_xx" == "y" ] ; then
      if [ "$os_name" = "SunOS" ]; then
        ps -fle|grep $prg_name|grep -v grep|grep -v "$prog_name -k"|grep -v "$prog_name -K"|awk '{print $4}'|xargs kill -9
      else
       psid=`ps -fle|grep $prg_name|grep -v grep|grep ^4|awk '{print $4}'`
       if [ "$psid" != "" ]; then
         #echo psid $psid
         kill -9 $psid
       fi
       cnt=`ps -fle|grep $prg_name|grep -v grep|grep -v "$prog_name -k"|grep -v "$prog_name -K"|grep ^0|wc -l`
       #ps -fle|grep $prg_name|grep -v grep|grep ^0
       #echo 2: $cnt
       if [ $cnt -gt 0 ] ; then
          psid2=`ps -fle|grep $prg_name|grep -v grep|grep -v "$prog_name -k"|grep -v "$prog_name -K"|grep ^0|head -1|awk '{print $4}'`
          #echo psid2 $psid2
          kill -9 $psid2
          sleep 1
          cnt=`ps -fle|grep $prg_name|grep -v grep|grep -v "$prog_name -k"|grep -v "$prog_name -K"|grep ^1|wc -l`
          #cnt=`ps -fle|grep $prg_name|grep -v grep|grep ^1|wc -l`
          #echo 3: $cnt
          if [ $cnt -gt 0 ] ; then
            #echo all
            ps -fle|grep $prg_name|grep -v grep|grep ^1|awk '{print $4}'|xargs kill -9
          fi
       fi
      fi
    fi
    exit
  elif  [ "$1" == "-G" ]; then
    echo "Graph Report generating...."
  else
    echo "Usage: `basename $0` <interval seconds> <repeat count> [-r|-k|-t|-b|-m|-f|-R]"
    echo "Example for run : sh `basename $0` 5 1000"
    echo "Example for logging : nohup sh `basename $0` 5 0 -r [logging directory] &"
    echo "Example for report : `basename $0` -R <file_name>"
    echo "[Options] -t [n] : Top process, -r [directory] : file logging, -b : Infiniband, -f : Force run, -p : pmem monitor, -k : Kill running, -x : CPU nice, -R [log_file] : make report"
    echo "If you want to run an infinite, set repeat count as 0. Example : sh `basename $0` 5 0"
    echo "If you have connection problem, run "dcli -g cell_group -l root -k\" or "dcli -g dbs_group -l root -k\""
    exit
  fi 
fi

if [ "$1" == "-R" ] ; then
  echo "Reporting generation of $2 file Start...."
elif  [ "$1" == "-G" ]; then
  echo "Realtime Graph Report generating...."
elif [ $1 -gt 1 ] && [ $1 -le 1000 ] ; then
  if [ $2 -eq 0 ] ; then
    echo "Interval : $1 seconds, Unlimited Looping "
  else
    echo "Interval : $1 sec, Looping count $2, Runing estimated time `expr $2 \* $1 \/ 3600` hours (`expr $2 \* $1 \/ 3600 \/ 24` days) " 
  fi
else
  echo "Interval seconds must be greater then 2 seconds or Interval must be first argument"
  echo "example : `basename $0` 5 1000 or `basename $0` 5 1000 -r"
  exit
fi

make_sa_exec()
{
   time_int=$1
   line=$2
   t=$3
   roce_y=$4

   cp /dev/null /tmp/sa_exec_${line}.sh
   if [ $roce_y -eq 0 ]; then
    time_i=1
    echo "cp /dev/null /tmp/sa_exec_tmp.txt" > /tmp/sa_exec_${line}.sh
    grep ${line} /tmp/sa_ibaddr_$t.tmp > /tmp/sa_ib_${line}.txt
    while [ $time_i -le $time_int ]
    do
      #for j in $(seq 1 2)
      #do
      #  paddr=`grep ${line}:$j /tmp/sa_ibaddr_$t.tmp | awk '{print $2}'`
      #  echo "/usr/sbin/perfquery -r $paddr $j 0xf000 |grep Data >> /tmp/sa_exec_tmp.txt &"  >> /tmp/sa_exec_${line}.sh
      #done
      while read vtmp
      do
        j=`echo $vtmp | awk '{ print $1 }' | awk -F":" '{print $2}'`
        paddr=`echo $vtmp | awk '{ print $2 }'`
        echo "/usr/sbin/perfquery -r $paddr $j 0xf000 |grep Data >> /tmp/sa_exec_tmp.txt &"  >> /tmp/sa_exec_${line}.sh
      done < /tmp/sa_ib_${line}.txt 
      #echo "wait"  >> /tmp/sa_exec_${line}.sh
      echo "sleep 1"  >> /tmp/sa_exec_${line}.sh
      time_i=`expr $time_i + 1`
    done
      while read vtmp
      do
        j=`echo $vtmp | awk '{ print $1 }' | awk -F":" '{print $2}'`
        paddr=`echo $vtmp | awk '{ print $2 }'`
        echo "/usr/sbin/perfquery -r $paddr $j 0xf000 |grep Data >> /tmp/sa_exec_tmp.txt &"  >> /tmp/sa_exec_${line}.sh
      done < /tmp/sa_ib_${line}.txt 
    echo "wait"  >> /tmp/sa_exec_${line}.sh
    echo "awk 'BEGIN {FS=\".\";rx=0;tx=0} { if (\$1 == \"PortRcvData:\")(rx+=\$22); else if (\$1==\"PortXmitData:\")(tx+=\$21)} END { printf(\"%s %s\n\", rx, tx) }' /tmp/sa_exec_tmp.txt" >> /tmp/sa_exec_${line}.sh
   else
     echo "/usr/sbin/ethtool -S re0 | grep x_bytes_phy > /tmp/sa_exec_tmp.txt" >>  /tmp/sa_exec_${line}.sh
     echo "/usr/sbin/ethtool -S re1 | grep x_bytes_phy >> /tmp/sa_exec_tmp.txt" >>  /tmp/sa_exec_${line}.sh
     echo "sleep $time_int" >>  /tmp/sa_exec_${line}.sh
     echo "/usr/sbin/ethtool -S re0 | grep x_bytes_phy >> /tmp/sa_exec_tmp.txt" >>  /tmp/sa_exec_${line}.sh
     echo "/usr/sbin/ethtool -S re1 | grep x_bytes_phy >> /tmp/sa_exec_tmp.txt" >>  /tmp/sa_exec_${line}.sh
     echo "awk 'BEGIN {rx=0;tx=0;rxb=0;txb=0} { if (\$1 == \"rx_bytes_phy:\" && NR<=4)(rxb+=\$2); else if (\$1==\"tx_bytes_phy:\" && NR<=4 )(txb+=\$2); else if (\$1 == \"rx_bytes_phy:\" && NR>4)(rx+=\$2); else if (\$1==\"tx_bytes_phy:\" && NR>4 )(tx+=\$2) } END { printf(\"%s %s\\n\", (rx-rxb)/$time_int , (tx-txb)/$time_int ) }' /tmp/sa_exec_tmp.txt" >>  /tmp/sa_exec_${line}.sh
   fi

}

make_pmem_dim()
{
     line=$1
     ssh ${line} ${SSH_CELL_OPTION} "ipmctl show -dimm |grep 0x |awk '{print \$1}' > /tmp/dim_list.txt"
     cp /dev/null /tmp/sa_pmem_${line}.sh
     echo "cp /dev/null /tmp/btx_$t.txt" > /tmp/sa_pmem_${line}.sh
     echo "while read line; do" >> /tmp/sa_pmem_${line}.sh
     echo "  ipmctl  show -dimm \$line -performance |grep \" Media\" >> /tmp/btx_$t.txt &" >> /tmp/sa_pmem_${line}.sh
     echo "done < /tmp/dim_list.txt" >> /tmp/sa_pmem_${line}.sh
     echo "wait" >> /tmp/sa_pmem_${line}.sh
     echo "awk -F\"=\" 'BEGIN {rsum=0;wsum=0} { if (\$1==\"   MediaReads\") (rsum=rsum+strtonum(\$2)); else ( wsum=wsum+strtonum(\$2) ) } END { printf \"%d %d\n\", rsum, wsum }' /tmp/btx_$t.txt" >> /tmp/sa_pmem_${line}.sh
     scp $SCP_CELL_OPTION /tmp/sa_pmem_${line}.sh ${line}:~/ 1>/dev/null
     echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sh ~/sa_pmem_${line}.sh`" >> /tmp/sap_org_$t.tmp &
}

sar_report()
{

rep_dbs_group_file="/tmp/rep_dbs_group"
rep_cell_group_file="/tmp/rep_cell_group"
if [ "$1" == "R" ]; then
  db_c_f=1
  io_p_f=1
  io_g_f=1
  if [ "$2" == "" ]; then
    logfile=`ls -t /tmp/saf*|tail -1`
    real_f=1
  else
    v_opt_f=`echo $2|cut -c1`
    if [ "$v_opt_f" == "-" ] ; then
      v_opt_tmp=`echo $2 | wc -c`
      v_opt_cnt=`expr v_opt_cnt - 1`
      for ((i=2;i<=v_opt_cnt;i++)) do
       v_opt_char=`echo $2 | wc -c$i`
       case $v_opt_char in
         c) g_db_cpu_f=1;;
         n) g_db_net_f=1;;
         m) g_db_mem_f=1;;
         t) g_db_roce_t_f=1;;
         r) g_db_roce_r_f=1;;
         C) g_cel_cpu_f=1 ;;
         F) g_cel_flash_p_f=1 ;;
         D) g_cel_disk_p_f=1 ;;
         P) g_cel_pmem_r_f=1 ;;
         Q) g_cel_flash_r_f=1 ;;
         O) g_cel_disk_r_f=1 ;;
         W) g_cel_flash_w_f=1 ;;
         X) g_cel_disk_w_f=1 ;;
         T) g_db_roce_t_f=1;;
         R) g_db_roce_r_f=1;;
         *) echo INPUT option error
            exit
       esac
      done
   
      if [ "$3" == "" ]; then
        logfile=`ls -t /tmp/saf*|tail -1`
        real_f=1
      else
        logfile=$3  
        real_f=2
      fi
    else
      logfile=$2  
      real_f=2
    fi
  fi
  logfile_header=`echo $logfile|awk -F"/" '{print $(NF)}'|awk -F"." '{print $(NF-1)}'`  
  #echo $logfile
else
  logfile=$1  
  logfile_header=`echo $logfile|awk -F"/" '{print $(NF)}'|awk -F"." '{print $(NF-1)}'`  
  real_f=0
fi
rep1=`grep -n '=' $logfile |head -1|awk -F":" '{print $1}'`
rep2=`grep -n '=' $logfile |head -2|tail -1|awk -F":" '{print $1}'`
rep3=`grep -n '-' $logfile |head -1|tail -1|awk -F":" '{print $1}'`
dstop=`expr $rep2 - 1`
dgap=`expr $dstop - $rep1 - 2 `
cstop=`expr $rep3 - 1`
cgap=`expr $cstop - $rep2 - 2 `

#echo db : $dstop $dgap
#echo cell : $cstop $cgap
head -${dstop} $logfile |tail -${dgap}|awk  -F":" '{print $1}' > $rep_dbs_group_file
head -${cstop} $logfile |tail -${cgap}|awk  -F":" '{print $1}' > $rep_cell_group_file
#cat $rep_dbs_group_file
#cat $rep_cell_group_file

interval=`grep -i interval $logfile |head -1 | awk -F"," '{ print $2 }' | awk -F":" '{ print $2 }'| awk '{ print $1 }'`
 
grep "Max" $logfile | grep "interval" | awk '{print $4 "-" $3 "-" $7 " " $5}' > /tmp/satr_time.txt 
tmp_file="/tmp/satr_all.txt"
tmp_file2="/tmp/satr2_all.txt"

size2=`head -1 $rep_cell_group_file | wc -c`
if [ $size2 -le 7 ]; then
   size2=0
else
   size2=`expr $size2 - 7`
fi
r_size=`expr $size2 + 7`

#awk -v size1=${r_size} '{ if ($2 == "TOT") { printf substr($0,1,size1)" "substr($0,10,7)" "substr($0,18,7)" "substr($0,25,7)" "substr($0,32,6)" "substr($0,38,6)" "substr($0,44,8)" "substr($0,52,7)" "substr($0,59,7)" "substr($0,66,7)" "substr($0,73,6)" "substr($0,79,6)" "substr($0,85,8)" "substr($0,93,7)" "substr($0,100,6)" "substr($0,106,8)" "substr($0,114,7)"\n"} else { print $0 } }' $logfile > $tmp_file2
# awk -v size1=${r_size} '{ if ($2 == "TOT") { printf substr($0,1,size1)" "substr($0,size1+1,7)" "substr($0,size1+9,7)" "substr($0,size1+16,7)" "substr($0,size1+23,6)" "substr($0,size1+29,6)" "substr($0,size1+35,8)" "substr($0,size1+43,7)" "substr($0,size1+50,7)" "substr($0,size1+57,7)" "substr($0,size1+64,6)" "substr($0,size1+70,6)" "substr($0,size1+76,8)" "substr($0,size1+84,7)" "substr($0,size1+91,6)" "substr($0,size1+97,8)" "substr($0,size1+105,7)"\n"} else { print $0 } }' $logfile > $tmp_file2
 awk -v size1=${r_size} '{ if ($2 == "TOT") { printf substr($0,1,size1)" "substr($0,size1+1,7)" "substr($0,size1+9,7)" "substr($0,size1+16,7)" "substr($0,size1+23,6)" "substr($0,size1+29,6)" "substr($0,size1+35,8)" "substr($0,size1+43,7)" "substr($0,size1+50,7)" "substr($0,size1+57,7)" "substr($0,size1+64,6)" "substr($0,size1+70,6)" "substr($0,size1+76,8)" "substr($0,size1+84,7)" "substr($0,size1+91,6)" "substr($0,size1+97,8)" "substr($0,size1+105,9)"\n"} else { print $0 } }' $logfile > $tmp_file2

sed -e "s/|/ /g" $tmp_file2 | sed -e "s/\* //" | sed -e "s/\://" | tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g" > $tmp_file
#echo "1. Time Header created"


if [ $real_f -eq 0 ]; then 
rm /tmp/all_db.txt /tmp/all_cell.txt 2> /dev/null
#cp $tmp_file /tmp/aa.txt
printf "What kind of report do you want 1) DB, 2) Cell, 3) DB+Cell : " 
read xx

if [ "$xx" == "" ]; then
 xx=1
fi

if [ $xx -eq 1 ] || [ $xx -eq 3 ] ; then
 printf "What kind of DBMS Node report do you want 1) CPU, 2) Memory, 3) CPU+Memory, 4) Network, 5) ALL : "
 read db_sel

 if [ "$db_sel" == "" ]; then
   db_sel=1
 fi

cat /tmp/satr_time.txt > /tmp/all_db_tmp.txt
while read line 
do
  case $db_sel in
  1) 
    grep $line $tmp_file | awk '{print $2 "," $3 "," $5 "," $6 }' > /tmp/satr_$line.txt 
    db_header=`echo $db_header",user,sys,idle,runq"`
    ;;
  2) 
    grep $line $tmp_file | awk '{print $7 "," $8 "," $9 }' > /tmp/satr_$line.txt 
    db_header=`echo $db_header",umem,rmem,swap"`
    ;;
  3) 
    grep $line $tmp_file | awk '{print $2 "," $5 "," $7 "," $8 }' > /tmp/satr_$line.txt 
    db_header=`echo $db_header",usr,idle,umem,rmem"`
    ;;
  4) 
    grep $line $tmp_file | awk '{print $10 "," $12 "," $18 "," $19 }' > /tmp/satr_$line.txt 
    db_header=`echo $db_header",eth_rv,eth_tr,ib_rv,ib_tr"`
    ;;
  5) 
    grep $line $tmp_file | awk '{print $2 "," $5 "," $7 "," $8 "," $10 "," $12 "," $18 "," $19 }' > /tmp/satr_$line.txt 
    db_header=`echo $db_header",usr,idle,umem,rmem,eth_rv,eth_tr,ib_tr,ib_tr"`
    ;;
  *) 
    echo INPUT error
    exit
  esac

  #wc -l /tmp/satr_$line.txt
  db_cnt=`wc -l /tmp/satr_$line.txt | awk '{ print $1 }'`
  $AWK '{ if ( FNR == NR ) { a[++z]=$0 } else { b[++x]=$0 } } END { for (j=1;j<=z;j++) { print a[j]", "b[j]} }'  /tmp/all_db_tmp.txt /tmp/satr_$line.txt > /tmp/all_db.txt
  cat /tmp/all_db.txt > /tmp/all_db_tmp.txt
done < $rep_dbs_group_file
fi

# Cell 
i=1
cell_sel=0
cell_sel2=0

if [ $xx -eq 2 ] || [ $xx -eq 3 ] ; then
 printf "What kind of the Cell Node report do you want 1) Total I/O, 2) I/O Max_pct, 3) CPU+INFINI, 4) ALL, 5) ALL(detail): " 
 read cell_sel
 printf "Which Cell node information do you want 1) Total Cell Sum, 2) Each Cell : " 
 read cell_sel2

 while read line 
 do
  if [ $cell_sel2 -eq 1 ]; then
    node_name="TOT"
  else
    node_name="$line"
  fi
  case $cell_sel in
  1)
    grep $node_name $tmp_file | awk '{print $2 "," $3+$4 "," $9+$10}' > /tmp/satr_$node_name.txt
    cell_header=",tot_mb,disk_mb,flash_mb"
    ;;
  2)
    grep $node_name $tmp_file | awk '{print $5 "," $6 "," $11 "," $12 }' > /tmp/satr_$node_name.txt
    cell_header=",dsk_avg,dsk_max,fls_avg,fls_max"
    ;;
  3)
    grep $node_name $tmp_file | awk '{print $15 "," $16 "," $17 }' > /tmp/satr_$node_name.txt
    cell_header=",cell_cpu,ib_rv,ib_tr"
    ;;
  4)
    grep $node_name $tmp_file | awk '{print $2 "," $6 "," $12 "," $15 "," $16+$17 }' > /tmp/satr_$node_name.txt
    cell_header=",tot_mb,dsk_max,fls_max,cell_cpu,ib_mb"
    ;;
  5)
    grep $node_name $tmp_file | awk '{print $2 "," $3 "," $4 "," $5 "," $6 "," $7 "," $8 "," $9 "," $10 "," $11 "," $12 "," $13 "," $14 "," $15 "," $16 "," $17 }' > /tmp/satr_$node_name.txt
    cell_header=",tot_mb,dsk_r_mb,disk_w_mb,dsk_avg,dsk_max,dsk_tps,dsk_svctm,fls_r_mb,fls_w_mb,fls_avg,fls_max,fls_tps,fls_svctm,cell_cpu,ib_r_mb,ib_t_mb"
    ;;
  *)
    echo INPUT error
    exit
  esac

  #echo 1input : $cell_sel 2input : $cell_sel2

  if [ $i -eq 1 ] ; then
      cat /tmp/satr_$node_name.txt > /tmp/all_cell_tmp.txt 
      cat /tmp/all_cell_tmp.txt > /tmp/all_cell.txt
     # read ttt
  else
      $AWK '{ if ( FNR == NR ) { a[++z]=$0 } else { b[++x]=$0 } } END { for (j=1;j<=z;j++) { print a[j]", "b[j]} }'  /tmp/all_cell_tmp.txt /tmp/satr_$node_name.txt > /tmp/all_cell.txt
      cat /tmp/all_cell.txt > /tmp/all_cell_tmp.txt
     # read ttt2
  fi
  i=`expr $i + 1`
  if [ $cell_sel2 -eq 1 ]; then
    #cell_cnt=`wc -l /tmp/all_cell.txt | awk '{ print $1 }'`
    cell_header2=$cell_header
    break 
  else
    cell_header2=`echo $cell_header2 $cell_header`
    
  fi
done < $rep_cell_group_file
cell_cnt=`wc -l /tmp/all_cell.txt  | awk '{ print $1 }'`
fi

printf "Input report duration second [ current interval : $interval sec ] : " 
read v_int

if [ $xx -eq 2 ] ; then
    $AWK '{ if ( FNR == NR ) { a[++z]=$0 } else { b[++x]=$0 } } END { for (j=1;j<=z;j++) { print a[j]", "b[j]} }'  /tmp/satr_time.txt /tmp/all_cell.txt > /tmp/all_cell_tmp.txt

  cat /tmp/all_cell_tmp.txt > /tmp/all_cell.txt
fi

if [ $cell_sel -ne 0 ] && [ -f /tmp/all_db.txt ] && [ -f /tmp/all_cell.txt ] ; then
    result_file="./sar_rpt_all_${db_sel}_${cell_sel}${cell_sel2}_${logfile_header}.csv"
    echo "Logging time" $db_header $cell_header2 > $result_file
    #if [ "$os_name" = "SunOS" ]; then
      $AWK '{ if ( FNR == NR ) { a[++z]=$0 } else { b[++x]=$0 } } END { for (j=1;j<=z;j++) { print a[j]", "b[j]} }'  /tmp/all_db.txt /tmp/all_cell.txt >> $result_file 
    #else
    #  awk '{ if ( FNR == NR ) { a[++z]=$0 } else { b[++x]=$0 } } END { for (j=1;j<=z;j++) { print a[j]", "b[j]} }'  /tmp/all_db.txt /tmp/all_cell.txt >> $result_file 
    #fi
    #echo cell_cnt : $cell_cnt db_cnt : $db_cnt
    if [ $db_cnt -ne $cell_cnt ]; then
      echo DB result count $db_cnt and Cell result count $cell_cnt is different. Check log file.
    fi
elif [ $cell_sel -eq 0 ] && [ -f /tmp/all_db.txt ] ; then 
    result_file="sar_rpt_db_${db_sel}_${logfile_header}.csv"
    echo "Logging time" $db_header > $result_file
    cat /tmp/all_db.txt >> $result_file 
else
    result_file="sar_rpt_cel_${cell_sel}${cell_sel2}_${logfile_header}.csv"
    echo "Logging time" $db_header $cell_header2 > $result_file
    cat /tmp/all_cell.txt >> $result_file
fi

# avg calucation  xxxxx

if [ $debug_f -eq 1 ] ; then
   echo v_int : $v_int
   echo interval : $interval
fi

if [ "$v_int" == "" ]; then
  echo "$result_file file generated with original interval $interval second."
elif [ $v_int -eq $interval ]; then
  echo "$result_file file generated with original interval $interval second."
else
  v_n_int=`expr $v_int \/ \( $interval \)`
  echo $v_n_int > d_loop.txt
  row_cnt=`wc -l $result_file | awk '{print $1}'` 
  row_cnt=`expr $row_cnt - 1`
  tail -$row_cnt $result_file > merge_t1.txt
  rec_cnt=`head -2 merge_t1.txt |tail -1 | awk -F"," '{print NF}'`

  r1=1 
  while [ $r1 -le $rec_cnt ] ; do
    if [ $r1 -eq $rec_cnt ] ; then
      awk -F"," '{ if ( FNR == NR ) { a1[++x]=$NF} else { vf=$1;n=1 } } END \
      { for(j=1;j<=x;j++) { if( (j-1) % vf == 0 || j == x ) { printf("%s\n", a1[j]); k++;n=1 } } }' merge_t1.txt d_loop.txt > merge_t2.txt 
    else
      awk -F"," '{ if ( FNR == NR ) { a1[++x]=$NF} else { vf=$1;n=1 } } END \
      { for(j=1;j<=x;j++) { if( (j-1) % vf == 0 || j == x ) { printf("%.1f\n", (c1[k]+a1[j])/n); k++;n=1 } \
        else { c1[k]=c1[k]+a1[j];n++ } } }' merge_t1.txt d_loop.txt > merge_t2.txt 
    fi

  #wc merge_t2.txt

    if [ $r1 -eq 1 ] ; then
      cp merge_t2.txt merge_c.txt
    else
      awk '{ if ( FNR == NR ) { a1[++z]=$0} else { a2[++x]=$0 } } END { for (j=1;j<=z;j++) { printf("%s,%s\n", a1[j], a2[j]) }  }' merge_t2.txt merge_c.txt > merge_c2.txt
     cp merge_c2.txt merge_c.txt
    fi

    awk -F"," '{ for(i=1;i<NF;i++) if( i == 1 ) {printf "%s", $i} else {printf ",%s", $i} ; printf "\n" }' merge_t1.txt > merge_t3.txt
    cp merge_t3.txt merge_t1.txt

    r1=`expr $r1 + 1`
  done

  head -1 $result_file  > result_head.txt
  cat result_head.txt  merge_c.txt > $result_file
  if [ $debug_f -eq 1 ] ; then
    rm merge_t3.txt merge_t2.txt merge_t1.txt merge_c.txt merge_c2.txt d_loop.txt result_head.txt
  fi
  echo "$result_file file regenerated with input interval $v_int second from original interval $interval second"
fi

else
  # graph
  echo "[Actual Report]"
  x_size=$X_AXIS_SIZE
  y_size=$Y_AXIS_SIZE
  y_max=1
  gcnt=`expr $dgap + 4` # Total Graph count
  tot_cnt=`grep TOT $logfile | wc -l`
  declare -A darr
  declare -A carr
  declare -A rarr
  declare -A tarr
  for ((n=1;n<=gcnt;n++)) do
    for ((i=0;i<=y_size;i++)) do
        darr[$n,$i,1]=`expr 100 - $i \* 100 \/ $y_size`
    done
  done
  v_dc=`echo $y_size $dgap |awk  '{printf("%.1f", $1/$2)}'`
  for ((i=0;i<=y_size;i++)) do
      k=`echo $y_size $dgap $i |awk  '{printf("%.0f", 100*$2-100*$2/$1*$3)}'`
      #k=`expr 100 \* $dgap - $i \* $v_dc \* $dgap `
      darr[1,$i,1]="${k}"
  done

  #cp $rep_dbs_group_file /tmp/sa_graph.txt 
  j=2
  while true
  do
    vx_size=`tput cols`
    x_size=`expr $vx_size \/ 2 \* 2 - 6`
    if [ $real_f -eq 1 ]; then
      vfile=`ls -tr /tmp/saf*|tail -1`
      n=1
      #DB
      if [ $db_c_f -eq 1 ]; then
        m=1
        vs=0 
        v2=1
        while read line
        do
         #v3=`grep $line $vfile `
         v1=`grep $line $vfile | tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g"| awk -v ys=$v_dc '{printf("%.0f", $2/(100/ys))}' `
         echo $line v2 : $v2 v1 : $v1 vs : $vs
         vs=`expr $vs + $v1` 
         for ((i=$v2;i<=$vs;i++)) do
           k=`expr $y_size - $i`
           darr[$n,$k,2]="X"
           carr[$n,$k,2]=$m
         done
         v2=`expr $v1 + 1`
         m=`expr $m + 1`
         darr[$n,0,0]=" DBMS CPU Util (%)"
        done < $rep_dbs_group_file 
        n=`expr $n + 1`
      fi
      #echo n value : $n
      #Cell
     if [ $io_p_f -eq 1 ]; then
     v2=`grep TOT $vfile |sed -e "s/|/ /g" | sed -e "s/\* //" | sed -e "s/\://" |tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g"| awk -v ys=$y_size '{printf("%.0f %.0f %.0f", $15/(100/ys), $12/(100/ys), $6/(100/ys))}'`
     #v1=`expr $v2 \/ \( 100 \/ $y_size \) + 1`
     #echo $line v2 : $v2 v1 : $v1
     v1=`echo $v2 | awk '{print $1}'`
     for ((i=1;i<=v1;i++)) do
       k=`expr $y_size - $i`
       darr[$n,$k,2]="X"
     done
     darr[$n,0,0]="Cell Total CPU Util (%)"

     n=`expr $n + 1`
     v1=`echo $v2 | awk '{print $2}'`
     for ((i=1;i<=v1;i++)) do
       k=`expr $y_size - $i`
       darr[$n,$k,2]="X"
     done
     darr[$n,0,0]="Cell Total Flash Util (%)"

     n=`expr $n + 1`
     v1=`echo $v2 | awk '{print $3}'`
     for ((i=1;i<=v1;i++)) do
       k=`expr $y_size - $i`
       darr[$n,$k,2]="X"
     done
     darr[$n,0,0]="Cell Total Disk Util (%)"
     n=`expr $n + 1`
     fi
     # IO Gbytes
     if [ $io_g_f -eq 1 ]; then
       v2=`grep TOT $vfile |sed -e "s/|/ /g" | sed -e "s/\* //" | sed -e "s/\://" |tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g"| awk -v ys=$y_size '{printf("%.0f %.0f %.0f %.0f", $3/1024, $9/1024, $18/1024, ($3+$9+$18)/1024)}'`
       v_max=`echo $v2 | awk '{print $4}'`
       echo $v2 v_max : $v_max y_mx : $y_max
       if [ $v_max -gt $y_max ]; then
         echo "MAX!!!! Changed"
         y_max=$v_max
         for ((i=0;i<=$y_size;i++)) do
           k=`echo $y_max $y_size $i  | awk '{ printf("%.0f", $1-$3*($1/$2)) }'`
           #k=`expr $y_max \- $i \* \( $y_max / $y_size \)`
           darr[$n,$i,1]="${k}"
           for ((m=2;m<=$x_size;m++)) do
             darr[$n,$i,$m]=""
             carr[$n,$i,$m]=0
           done
         done
         m_size=$x_size
       else
         m_size=2
       fi

       rarr[$n,1,2]=`echo $v2 | awk '{printf("%.2f", $1)}'`
       rarr[$n,2,2]=`echo $v2 | awk '{printf("%.2f", $2)}'`
       rarr[$n,3,2]=`echo $v2 | awk '{printf("%.2f", $3)}'`

       for ((m=2;m<=$m_size;m++)) do
         v11=`echo ${rarr[$n,1,$m]} | awk -v y_max=$y_max -v y_size=$y_size  '{printf("%.0f", $1/(y_max/y_size))}'`
         v12=`echo ${rarr[$n,2,$m]} | awk -v y_max=$y_max -v y_size=$y_size  '{printf("%.0f", $1/(y_max/y_size))}'`
         v12v=`expr $v12 + $v11`
         if [ $v13v -gt 0 ]; then
          for ((i=1;i<=$v11;i++)) do
           k=`expr $y_size - $i`
           darr[$n,$k,$m]="X"
            carr[$n,$k,$m]=1
          done
          for ((i=$v11;i<$v12v;i++)) do
           k=`expr $y_size - $i - 1 `
           darr[$n,$k,$m]="X"
           carr[$n,$k,$m]=2
           #echo carr[$n,$k,$m]=2
          done
          if [ $roce_y -eq 1 ]; then
            v13=`echo ${rarr[$n,3,$m]} | awk -v y_max=$y_max -v y_size=$y_size  '{printf("%.0f", $1/(y_max/y_size))}'`
            v13v=`expr $v13 + $v12v`
            for ((i=$v12v;i<$v13v;i++)) do
             k=`expr $y_size - $i - 1`
             darr[$n,$k,$m]="X"
             carr[$n,$k,$m]=3
             #echo rarr[$n,$k,$m]=3
            done
          fi
         fi
         #echo v11 : $v11 v12 : $v12 v13 : $v13 v12v : $v12v v13v : $v13v
       done
       if [ $roce_y -eq 1 ]; then
         darr[$n,0,0]="Cell Total PMEM : X, Flash : X Disk : X"
       else
         darr[$n,0,0]="Cell Total Flash : X Disk : X"
       fi
       n=`expr $n + 1`
     fi
        
       #for ((i=1;i<=v1;i++)) do
       #  k=`expr $y_size - $i`
       #  darr[$n,$k,2]="X"
       #done
     #n=`expr $n + 1`
     #v2=`grep TOT $vfile |sed -e "s/|/ /g" | sed -e "s/\* //" | sed -e "s/\://" |tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g"| awk -v ys=$y_size '{printf("%.0f", $11/(100/ys))}'`
     #v1=`expr $v2 \/ \( 100 \/ $y_size \) + 1`
     #echo $line v2 : $v2 v1 : $v1
     #for ((i=1;i<=v1;i++)) do
     #  k=`expr $y_size - $i`
     #  darr[$n,$k,2]="X"
     #done
     #darr[$n,0,0]="Cell Total Flash Util (%)"

     v2=`grep "Max" $vfile | grep "interval" | awk '{print $5}' | awk -F":" '{print $1$2}'` 
     tarr[0,2]=`echo $v2|cut -c1-1`
     tarr[1,2]=`echo $v2|cut -c2-2`
     tarr[2,2]="/"
     tarr[3,2]=`echo $v2|cut -c3-3`
     tarr[4,2]=`echo $v2|cut -c4-4`

    else #logfile 
      n=1
      #pg_cnt=`expr $x_size \/ 2 \* $j`
      #pg_cnt=`expr $tot_cnt - $x_size \/ 2 \* \( $j - 2 \)`
      pg_cnt=`expr $tot_cnt - 10 \* \( $j - 2 \)`
      while read line
      do
        grep $line $logfile |head -$pg_cnt | tail -$x_size  | tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g"| awk -v ys=$y_size '{printf("%.0f\n", $2/(100/ys))}' > /tmp/sa_log_$n.txt 
        m=2
        while read line2
        do
          for ((i=1;i<=line2;i++)) do
            k=`expr $y_size - $i`
            darr[$n,$k,$m]="X"
          done
          m=`expr $m + 1`
        done < /tmp/sa_log_$n.txt
        darr[$n,0,0]=$line" : CPU Util (%)"
        n=`expr $n + 1`
      done < $rep_dbs_group_file 
      #echo "DB CPU assign END"

      grep "TOT" $logfile |head -$pg_cnt | tail -$x_size | sed -e "s/\* //" | sed -e "s/\://" | tr '\033[' ' ' | sed -e "s/ 1\;32m//g" | sed -e "s/ 1\;31m//g" | sed -e "s/ 00m//g"| awk -v ys=$y_size '{printf("%.0f\n", $15/(100/ys))}' > /tmp/sa_log_$n.txt 
      m=2
      while read line2
        do
          for ((i=1;i<=line2;i++)) do
            k=`expr $y_size - $i`
            darr[$n,$k,$m]="X"
          done
          m=`expr $m + 1`
        done < /tmp/sa_log_$n.txt
      darr[$n,0,0]=$line" : CPU Util (%)"
      n=`expr $n + 1`
      #echo "Cell CPU assign END"

      grep "Max" $logfile | grep "interval" | awk '{print $5}' | awk -F":" '{print $1$2}'|head -$pg_cnt | tail -$x_size > /tmp/sa_log_$n.txt
      m=2
      b_line=""
      while read line2
      do
        if [ "$b_line" != "$line2" ] ; then
          tarr[0,$m]=`echo $line2|cut -c1-1`
          tarr[1,$m]=`echo $line2|cut -c2-2`
          tarr[2,$m]="/"
          tarr[3,$m]=`echo $line2|cut -c3-3`
          tarr[4,$m]=`echo $line2|cut -c4-4`
        else
          tarr[0,$m]=""
          tarr[1,$m]=""
          tarr[2,$m]=""
          tarr[3,$m]=""
          tarr[4,$m]=""

        fi
        m=`expr $m + 1`
        b_line=$line2
      done < /tmp/sa_log_$n.txt
      #echo "Time assign END"
    fi
    gcnt=`expr $n - 1`

    # Write graph
    clear
    for ((n=1;n<=gcnt;n++)) do
    echo ${darr[$n,0,0]}
    for ((m=0;m<y_size;m++)) do
      printf "%3d | " ${darr[$n,$m,1]}
      for ((i=2;i<x_size;i++)) do
        if [ "${darr[$n,$m,$i]}" == "" ] ; then
         printf " "
        else
         v_col=${carr[$n,$m,$i]}
         printf "\033[1;3${v_col}m%s\033[00m" ${darr[$n,$m,$i]}
        fi
      done
      printf "\n"
    done
    printf "     "
    for ((i=0;i<x_size;i++)) do
      printf "-"
    done
    printf "\n"
    done 
    # HH:MI 
    for ((i=0;i<5;i++)) do
      printf "    "
      for ((m=0;m<x_size;m++)) do
        if [ "${tarr[$i,$m]}" == "" ] ; then
           printf " "
        else
          printf "%s" ${tarr[$i,$m]}
        fi
      done
      printf "\n"
    done


   if [ $real_f -eq 1 ]; then
    # value move
    for ((n=1;n<=gcnt;n++)) do
      for ((i=x_size;i>1;i--)) do
        k=`expr $i + 1`
        for ((m=0;m<y_size;m++)) do
          darr[$n,$m,$k]=${darr[$n,$m,$i]}
          carr[$n,$m,$k]=${carr[$n,$m,$i]}
        done
        for ((m=1;m<=3;m++)) do
          rarr[$n,$m,$k]=${rarr[$n,$m,$i]}
        done
      done
      for ((m=0;m<y_size;m++)) do
        darr[$n,$m,2]=""
        carr[$n,$m,2]=""
      done
    done 

      for ((i=x_size;i>1;i--)) do
        k=`expr $i + 1`
        for ((m=0;m<5;m++)) do
          tarr[$m,$k]=${tarr[$m,$i]}
        done
      done
      for ((m=0;m<5;m++)) do
        tarr[$m,2]=""
      done
      j=`expr $j + 1`
      sleep 5
   else
     xxx="N"
     printf " Next Page Press N, Prev Page Press P , Count (ex : P 10 ) : "
     read -r xxx skip_cnt
     #read -n1 xxx
     #printf "\n"
     #moved=`cat /dev/stdin`  
     if [ "$skip_cnt" == "" ] ; then
       skip_cnt=1 
     fi 
     if [ "$xxx" == "Q" ] || [ "$xxx" == "q" ] ; then
        exit
     elif [ "$xxx" == "P" ] || [ "$xxx" == "p" ] ; then
        j=`expr $j + $skip_cnt`
     else
       if [ $pg_cnt -eq $tot_cnt ]; then
          echo "This is last page. it will be reloaded."
       else
          j=`expr $j - $skip_cnt`
       fi
     fi
     echo "---- Wait a moment !!!!"
     for ((n=1;n<=gcnt;n++)) do
      for ((i=x_size;i>1;i--)) do
        for ((m=0;m<y_size;m++)) do
          darr[$n,$m,$i]=""
        done
      done
     done

     #${tarr[0,2]}${tarr[1,2]}":"${tarr[0,4]}${tarr[1,5]}" ~ "${tarr[0,x_size]}${tarr[1,2]}":"${tarr[0,4]}${tarr[1,5]} 
   fi

  done

fi


#rm -f /tmp/satr*.txt
#rm -f /tmp/all_*.txt

}

# Main Product identification
# Exalog removed 2020/12/31
prod=ex

# OS User accept
if [ "$user_name" == "root" ]; then
   dbuser=root
   celluser=root
   #rm -rf /tmp/sa*.tmp
   find /tmp/sa*.tmp  -mmin +60 2>/dev/null | xargs rm -f
else
   dbuser=`id -u -n`
   celluser=celladmin
   t=${t}o
   #rm -rf /tmp/sa*o.tmp
   find /tmp/sa*o.tmp  -mmin +60 2>/dev/null | xargs rm -f
   echo "If you have a permission problem, execute \"dcli -g cell_group -k\""
   ib_f=1
fi

# OS identification
if [ "$os_name" = "SunOS" ]; then
   ora_home=/export/home/oracle
   v_oratab="/var/opt/oracle/oratab"
   v_crs_home_bin=$(ps -ef |grep crsd.bin|grep -v grep|awk '{print $9}'|head -1)
   AWK=nawk
else
   ora_home=/home/oracle
   #os_version=`cat /etc/redhat-release | awk '{print $7*100}'`

   vm_f=`cat /etc/redhat-release | awk '{print $2}'`
   #echo $vm_f
   os_version=`cat /etc/oracle-release | awk '{print $5}' | awk -F"." '{print $1*100 + $2}'`
   v_oratab="/etc/oratab"
   v_crs_home_bin=$(ps -ef |grep crsd.bin|grep -v grep|awk '{print $8}'|head -1)
   AWK=awk
fi

if [ -f ./dbs_group ] ; then
   v_dbs_group_file="./dbs_group"
elif [ -f /root/cell_group ] && [ ${celluser} = "root" ] ; then
   v_dbs_group_file="/root/dbs_group"
elif [ -f $ora_home/dbs_group ] ; then
   v_dbs_group_file="$ora_home/dbs_group"
else
   if  [ "$1" == "-R" ]; then
        echo "DB, Cell information based on logfile."
   else
    if [ "$v_crs_home_bin" == "" ] ; then 
     if [ -f /tmp/saf_dbs_group ]; then
      echo "/tmp/saf_dbs_group will be used because of csrd.bin is stoptted." 
     else
        echo "csrd.bin must be started for sar.sh"
        exit 
     fi
    else
     v_crs_home_bin=$(dirname $v_crs_home_bin 2>/dev/null)
     $v_crs_home_bin/olsnodes > /tmp/saf_dbs_group
    fi
    v_dbs_group_file="/tmp/saf_dbs_group"
  fi
fi

if [ -f ./cell_group ] ; then
  v_cell_group_file="./cell_group"
elif [ -f /root/cell_group ] && [ ${celluser} = "root" ] ; then
  v_cell_group_file="/root/cell_group"
elif [ -f $ora_home/cell_group ] ; then
  v_cell_group_file="$ora_home/cell_group"
else
  echo "cell_group file doesn't exists in ./cell_group,/root/cell_group, $v_cell_group_file. Temporary cell_group file is made as /tmp/saf_cell_group"
  #v_crs_home=$(echo $v_crs_home_bin|sed 's/\/bin//g')
  CELLIP=/etc/oracle/cell/network-config/cellip.ora
  cp /dev/null /tmp/saf_cell_group
  for cell_ip in `cat $CELLIP|cut -d\" -f2|cut -d\; -f1`
  do
    cellname_full=$(cat /etc/hosts|grep -w "$cell_ip"|awk '{print $NF}'|cut -d'-' -f1)
    echo $cellname_full|awk '{print $1}' >> /tmp/saf_cell_group
  done
  v_cell_group_file="/tmp/saf_cell_group"
fi

if [ "$prod" == "xl" ] ; then
 if [ -f ./zfs_group ] ; then
   v_zfs_group_file="./zfs_group"
 else
   df -t nfs |grep ":"|awk -F":" '{print $1}' >> /tmp/saf_cell_group
   v_zfs_group_file="/tmp/saf_zfs_group"
 fi
fi

#cat /tmp/saf_dbs_group /tmp/saf_cell_group

# ssh option seting
SSH_CELL_OPTION="-o ConnectTimeout=5 -n -q -p 22 -l $celluser"
SSH_DB_OPTION="-o ConnectTimeout=5 -n -q -p 22 -l $dbuser"
SCP_CELL_OPTION="-P 22 "
SCP_DB_OPTION="-P 22 "
SSH_ZFS_OPTION="-o ConnectTimeout=5 -n -q -l root"


#interval=`expr $1 + 2`
#if [ $log_file ]; then
#   touch /tmp/.sar_start
#   sleep `expr $1 + 2`
#   log_file=`find /tmp/saf_*.tmp  -anewer /tmp/.sar_start| sort | tail -1`
#fi

# Argument accepting
if [ $# -le 3 ]; then
  if  [ "$1" == "-R" ]; then
    sar_report $2
    exit
  elif [ "$1" == "-G" ]; then 
    if [ $# -le 1 ]; then
      sar_report "R"
    else
      sar_report "R" $2
    fi
    exit
  fi
fi

for arg in $*
do
  case $arg in
  -r)
    if [ "$4" == "" ] || [ "`echo $4 | cut -b1-1`" == "-" ] ; then
      log_dir=`pwd`
    else
      log_dir=$4
      if [ ! -d $log_dir ] ; then
        mkdir -p $log_dir 
      fi
    fi
    file_name=sar_`date +%Y%m%d`.log 
    #log_dir=/u01/app/oracle/sar
    #psid=`ps -fle|grep $prg_name|grep -v grep|grep ^4|awk '{print $4}'`
    #if [ "$psid" == "" ]; then
    #  echo $prg_name $psid is not running
    #else
    #  echo kill ps id : $psid usage "sh $prg_name -k"
    #fi
    echo "$log_dir/$file_name" > /tmp/sar_log_dir.txt
    echo "Current screen will be saved as $log_dir/$file_name"
    log_f=1
    ;;
  -d)
    echo "Warning : It can make a trouble on MS server of cell nodes." 
    dsk_f=1
    ;;
  -t)
   top_f=1
   if [ "$4" == "" ] || [ "`echo $4 | cut -b1-1`" == "-" ]  ; then
     top_cnt=1
   else
     top_cnt=$4
   fi
    ;;
  -m)
   echo DB Monitoring start
   mon_f=1
    ;;
  -b)
   echo IB Monitoring does not start, Only one user can run with this options
   ib_f=1
    ;;
  -f)
   echo Other session is runing, but this run without IB monitor.
   run_f=1
   ib_f=1
    ;;
  -x)
   echo Extend Display 
   ext_f=1
    ;;
  -g)
   echo Debug Mode Display 
   debug_f=1
    ;;
  -p)
   echo PMEM IO Display 
   pmem_f=1
    ;;
  -v)
   echo OVM Mode Display 
   ovm_f=1
    ;;
  -o)
   echo Read only mode
   readonly_f=1
    ;;
 esac
done


#echo logfile_name : $log_file
   wflag=0
if [ $run_f -eq 1 ] || [ $log_f -eq 1 ]; then 
  echo "Run start"
elif [ $readonly_f -eq 1 ]; then
   rep_i=0
   while [ $rep_i -le $2 ] 
   do
     log_file=`find /tmp/saf_*.tmp  -mmin -2 2>/dev/null | sort | tail -1`
     if [ $log_file ]; then
       cat $log_file
     else
       echo "Data refresh is stopped."
     fi
     sleep $1
     if [ $2 -gt 0 ] ; then
       rep_i=`expr $rep_i + 1`
     fi
   done
else
  log_file=`find /tmp/saf_*.tmp  -mmin -1 2>/dev/null | sort | tail -1` 
  if [ $log_file ] ; then
   wflag=0
   interval=`head -1 $log_file | $AWK '{ print $10 }' | $AWK -F":" '{print $2}'`
   if [ $dbuser == "root" ] ; then
      int_time=`expr $interval + 10`
   else
      int_time=`expr $interval + 60`
   fi
   while [ $wflag -eq 0 ] 
   do
     log_file=`find /tmp/saf_*.tmp  -mmin -1 2>/dev/null | sort | tail -1`
     #echo readonly : $readonly_f
     wflag=0
     if [ $log_file ]; then
       ltime=`head -1 $log_file | awk '{ print $5 }' | awk -F":" '{print $1$2$3}'`
       ctime_sec=`date +%S`
       ctime=`date +%H%M%S`
       #echo ctime : $ctime ctime_sec : $ctime_sec interval : $interval
       if [ $ctime_sec -le $interval ] ; then
         dtime=0
       else
         dtime=`expr $ctime - $ltime`
       fi
       #echo diffv $dtime $ctime $ltime
       #log_file=`find /tmp/saf_*.tmp  -mmin -1`
       #clear
       #echo $log_file
       #echo "time" $ltime $ctime $dtime int : $interval
       if [ $int_time -le $dtime ]; then
          echo Session is not running. Now you become a original. Last time : $ltime, Current time : $ctime, Gap : $dtime
          wflag=1
       else
          if [ $log_f -eq 1 ]; then
             file_name=sar_`date +%Y%m%d`.log
             cat $log_file  >> /tmp/$file_name
          else
             cat $log_file
             echo Other session is runing, This is copy image..
          fi
          sleep $1 
       fi
     else
       wflag=1
       echo Session is not running. Now you become a original.
     fi
   done
  fi
fi

# hostname size setting
#size1=`head -1 $v_dbs_group_file | wc -c`
size1t=`awk 'BEGIN {mx=0} { if (mx < length($1)) (mx=length($1))} END { print mx + 1 }' $v_dbs_group_file`

if [ "$prod" == "xl" ] ; then
  size2=`head -1 $v_zfs_group_file | wc -c`
else
  size2=`head -1 $v_cell_group_file | wc -c`
fi

if [ $size1t -le 7 ]; then
   size1=0
else
   size1=`expr $size1t - 7`
fi
if [ $size2 -le 7 ]; then
   size2=0
else
   size2=`expr $size2 - 7`
fi
for x in `seq 1 $size1`; do spa1=$spa1"Z"; done
for z in `seq 1 $size2`; do spa2=$spa2"Z"; done

/usr/sbin/ibaddr -P 1 1>/dev/null 2>/tmp/ib_chk.txt
if [ "`cat /tmp/ib_chk.txt`" == "" ]; then
 #echo IB
 roce_y=0
else
 #echo 100G
 roce_y=1
 #pmem_f=1
fi 
#echo roce $roce_y

echo "Real sar start"

cp /dev/null /tmp/sag_org_$t.tmp
cp /dev/null /tmp/sai_org_$t.tmp
cp /dev/null /tmp/sap_org_$t.tmp
cp /dev/null /tmp/sa_ibaddr_$t.tmp
cp /dev/null /tmp/sa_osv_$t.tmp
cp /dev/null /tmp/sa_dsk_$t.tmp
cp /dev/null /tmp/sa_model_$t.tmp
cp /dev/null /tmp/sa_flash_$t.tmp
cp /dev/null /tmp/sa_hard_$t.tmp


while read line
do
  if [ "${line#"${line%%[![:space:]]*}"}" == "" ]; then
    echo Space line in $v_cell_group_file is not permitted. Please remove this line. 
    exit
  fi
  #echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} /usr/bin/rds-info -c | grep bytes | awk 'BEGIN {rx=0;tx=0} { if ($1 == "recv_rdma_bytes")(rx=$2); else if ($1=="send_rdma_bytes")(tx=$2)} END { printf(\"%s %s\", rx, tx) }' 2>/dev/null 3>/dev/null`" >> /tmp/sag_org_$t.tmp _phy

  if [ $roce_y -eq 0 ]; then
    if [ "$user_name" == "root" ]; then
      echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} \"/usr/sbin/ethtool -S ib0 | grep x_bytes;/usr/sbin/ethtool -S ib1 | grep x_bytes_phy\" | awk 'BEGIN {rx=0;tx=0} { if (\$1 == \"rx_bytes:\")(rx+=\$2); else if (\$1==\"tx_bytes:\")(tx+=\$2)} END { printf(\"%s %s\", rx, tx) }' 2>/dev/null 3>/dev/null`" >> /tmp/sag_org_$t.tmp &
      for j in $(seq 1 2)
      do
        echo ${line}:$j  "`ssh ${line} ${SSH_CELL_OPTION} /usr/sbin/ibaddr -P $j | awk '{print $7}'`" >> /tmp/sa_ibaddr_$t.tmp &
      done
      echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} /usr/sbin/exadata.img.hw --get model 2>/dev/null`" >> /tmp/sa_model_$t.tmp &
    else
      #printf "Please give me the cell node ${line} model. example (X7, X6, X5) : "
      #read model_name
      #echo ${line}: $model_name"-2L" >> /tmp/sa_model_$t.tmp
      echo "${line}: ORACLE SERVER X7-2L" >> /tmp/sa_model_$t.tmp
    fi
  else
   # echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} \"/usr/sbin/ethtool -S re0 | grep x_bytes_phy;/usr/sbin/ethtool -S re1 | grep x_bytes_phy\" | awk 'BEGIN {rx=0;tx=0} { if (\$1 == \"rx_bytes_phy:\")(rx+=\$2); else if (\$1==\"tx_bytes_phy:\")(tx+=\$2)} END { printf(\"%s %s\", rx, tx) }' 2>/dev/null 3>/dev/null`" >> /tmp/sag_org_$t.tmp &
    #ssh ${line} ${SSH_CELL_OPTION} "ipmctl show -dimm |grep 0x |awk '{print \$1}' > /tmp/dim_list.txt" &
    echo "${line}: ORACLE SERVER X8-2L" >> /tmp/sa_model_$t.tmp
  fi
  echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} cellcli -e \"list celldisk attributes deviceName where name like \'CD_00.*\' \"`" >> /tmp/sa_dsk_$t.tmp &
  echo ${line}: `ssh ${line} ${SSH_CELL_OPTION} cellcli -e \"list physicaldisk attributes devicename where diskType=\'M2Disk\' \"` >> /tmp/sa_m2_$t.tmp &
  echo ${line}: `ssh ${line} ${SSH_CELL_OPTION} cellcli -e \"list celldisk where diskType = \'FlashDisk\' \"|wc -l` >> /tmp/sa_flash_$t.tmp &
  echo ${line}: `ssh ${line} ${SSH_CELL_OPTION} cellcli -e \"list celldisk where diskType = \'HardDisk\' \"|wc -l` >> /tmp/sa_hard_$t.tmp &

done < $v_cell_group_file
wait

if [ "$user_name" == "root" ]; then
  sa_ibaddr_t=`ibstatus |grep base | wc -l` 
fi

arr_i=1
while read line
do
  if [ "${line#"${line%%[![:space:]]*}"}" == "" ]; then
    echo Space line in $v_dbs_group_file is not permitted. Please remove this line. 
    exit
  fi
  echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} /usr/bin/rds-info -c 2>/dev/null | grep user | awk 'BEGIN {rx=0;tx=0} { if ($1 == "copy_to_user")(rx=$2); else if ($1=="copy_from_user")(tx=$2)} END { printf(\"%s %s\", rx, tx) }' 2>/dev/null 3>/dev/null`" >> /tmp/sai_org_$t.tmp &
  if [ $roce_y -eq 0 ]; then
    if [ "$user_name" == "root" ]; then
      ssh ${line} ${SSH_CELL_OPTION} "/usr/sbin/ibstatus |grep -e port -e base |awk -v vline=${line} '{ if (\$1 == \"Infiniband\") { a[y++]=\$5 } else { b[z++]=\$3 } } END { for (j=0;j<z;j++) { print vline\":\"a[j]\" \"b[j]} }'" >> /tmp/sa_ibaddr_$t.tmp &
      #ssh ${line} ${SSH_DB_OPTION} ibstatus |grep base 2>/dev/null | $AWK -v line=${line} '{print line ": " $3}' >> /tmp/sa_ibaddr_$t.tmp &
      #for j in $(seq 1 2)
      #do
      #  echo ${line}:$j  "`ssh ${line} ${SSH_CELL_OPTION} /usr/sbin/ibaddr -P $j | awk '{print $7}'`" >> /tmp/sa_ibaddr_$t.tmp &
      #done
    fi
  fi
  if [ "$os_name" = "SunOS" ]; then
    echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} cat /etc/release| head -1 | awk '{print $3 }' | awk -F\".\" '{print $1*100 + $2}'`" >> /tmp/sa_osv_$t.tmp &
    os_type=`head -1  /etc/release| awk '{print $4}'`
  else
    echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} cat /etc/oracle-release | awk '{print $5}' | awk -F\".\" '{print $1*100 + $2}'`" >> /tmp/sa_osv_$t.tmp &
  fi
  #arr_i=`expr $arr_i + 1`
done < $v_dbs_group_file
wait

arr_i=1
while read line
do     
  if [ "$celluser" == "root" ]; then
    make_sa_exec $1 $line $t $roce_y
    scp $SCP_CELL_OPTION /tmp/sa_exec_${line}.sh ${line}:~/ 1>/dev/null
    #echo "PMEM from cellsrvstat "
    if [ $roce_y -eq 1 ] ; then
      echo "cellsrvstat  -stat=pmemc_sreadh,pmemc_spopulate,pmemc_ncdrsz,net_rxb,net_txb -short -interval=$1 -count=2 | tail -8 | awk 'BEGIN {rsum=0;wsum=0;msum=0;rx=0;tx=0} { if (\$1==\"pmemc_sreadh\") (rsum+=\$2); else if (\$1==\"pmemc_spopulate\") (wsum+=\$2); else if (\$1==\"net_rxb\") (rx+=\$2); else if (\$1==\"net_txb\") (tx+=\$2); else ( msum+=\$2) } END { printf \"%d %d %d %d %d\n\", rsum / $1, wsum / $1, msum / $1, rx / $1, tx / $1 }'" >  /tmp/sa_pmem2_${line}.sh
      scp $SCP_CELL_OPTION /tmp/sa_pmem2_${line}.sh ${line}:~/ 1>/dev/null
    fi
    if [ $pmem_f -eq 1 ] ; then
      make_pmem_dim $line $t
    fi
  fi
  sa_dsk[$arr_i]=`grep $line /tmp/sa_dsk_$t.tmp | awk '{print $2}'` 
  sa_model[$arr_i]=`grep $line /tmp/sa_model_$t.tmp | awk '{print $NF}'` 
  sa_hard[$arr_i]=`grep $line /tmp/sa_hard_$t.tmp | awk '{print $NF}'` 
  if [ ${sa_hard[$arr_i]} -eq 0 ] ; then
     sa_hard[$arr_i]=1
  fi
  if [ ${sa_model[$arr_i]} = "X7-2L" ] || [ ${sa_model[$arr_i]} = "X8-2L" ] ; then 
    sa_m2v1[$arr_i]=`grep $line /tmp/sa_m2_$t.tmp | awk -F'/' '{print $3}'` 
    sa_m2v2[$arr_i]=`grep $line /tmp/sa_m2_$t.tmp | awk -F'/' '{print $5}'` 
    sa_flash[$arr_i]=`grep $line /tmp/sa_flash_$t.tmp | awk '{print $NF*2}'` 
  else
    sa_m2v1[$arr_i]=sda 
    sa_m2v2[$arr_i]=sdb
    sa_flash[$arr_i]=`grep $line /tmp/sa_flash_$t.tmp | awk '{print $NF}'` 
  fi
  arr_i=`expr $arr_i + 1`
done < $v_cell_group_file
wait
#cat /tmp/sa_m2_$t.tmp

arr_i=1
while read line
do
  if [ "$dbuser" == "root" ]; then
    make_sa_exec $1 $line $t $roce_y
    scp $SCP_DB_OPTION /tmp/sa_exec_${line}.sh ${line}:~/ 1>/dev/null
  fi
  sa_osv_db[$arr_i]=`grep $line /tmp/sa_osv_$t.tmp | awk '{print $2}'` 
  arr_i=`expr $arr_i + 1`
done < $v_dbs_group_file

if [ $debug_f -eq 1 ] ; then
  cat /tmp/sa_osv_$t.tmp
  cat /tmp/sa_dsk_$t.tmp
  cat /tmp/sa_model_$t.tmp
  echo $v_dbs_group_file
  cat $v_dbs_group_file
  echo $v_cell_group_file
  cat $v_cell_group_file
fi

if [ $2 -eq 0 ] ; then
 i=0
fi

start_flag=0
### Main start
while [ $i -le $2 ]
do
 issue_date=`date +%H:%M:%S`
 start_time=`date +%s%N`

 cp /dev/null /tmp/sad_$t.tmp
 cp /dev/null /tmp/sadd_$t.tmp
 cp /dev/null /tmp/sadd1_$t.tmp
 cp /dev/null /tmp/sadd2_$t.tmp
 arr_i=1
 while read line
 do
  if [ "$os_name" = "SunOS" ]; then
   echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} sar -u -r -q $1 1|tail -4 | awk 'BEGIN {ucpu=0;scpu=0;memu=0;swapu=0;icpu=0;runq=0.0} {if (length( \$1 + \$2 ) > 5 )  (memu=\$1) (swapu=\$2); else if (NR==1) (ucpu=\$2)(scpu=\$3)(wcpu=\$4)(icpu=\$5); else if (NR==3) (runq=\$1); else (xxx=\$1); } END { print ucpu \" \" scpu \" \" wcpu \" \" icpu \" \" runq \" \" 0 \" \" memu/1024/1024 \" \" swapu/1024/1024 }' 2>/dev/null 3>/dev/null`" >> /tmp/sad_$t.tmp &
   echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} netstat -n -P tcp -s $1 2 |egrep \"tcpOutDataBytes|tcpInInorderBytes\" |tail -2 |awk -F\"= \" '{print $2 \" \" $3}'| awk 'BEGIN { eth_r=0;eth_t=0;eth_rp=0;eth_tp=0} {if (\$2==\"tcpOutDataBytes\")(eth_tp=\$1)(eth_t=\$3); else (eth_rp=\$1)(eth_r=\$3) } END { print eth_r \" \" eth_rp \" \" eth_t \" \" eth_tp }' 2>/dev/null 3>/dev/null`" >> /tmp/sadd_$t.tmp &
   echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} prtconf |grep Mem | nawk '{ print $3/1024 }'`" >> /tmp/sadd1_$t.tmp &
   echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} swap -s -h | nawk '{ print $8 $10 }'`" >> /tmp/sadd2_$t.tmp &
  else
   #os_v=`grep ${line} /tmp/sa_osv_$t.tmp|awk '{print $2}'`
   os_v=${sa_osv_db[$arr_i]}
   #echo ARR_I : $arr_i Value : ${sa_osv_db[$arr_i]} OS_V : $os_v
   if [ ${os_v:-0} -ge 600 ]; then
    echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} sar -u -q -n DEV $1 1|grep Average | awk 'BEGIN {ucpu=0;scpu=0;memu=0;swapu=0;icpu=0;eth_r=0.0;eth_t=0.0;ib_r=0.0;ib_t=0.0;eth_rp=0.0;eth_tp=0.0;runq=0.0} {if (length( \$2 + \$3 ) == 8 || length( \$2 + \$3 ) == 9)  (memu=\$4) (swapu=\$7); else if (\$2==\"all\") (ucpu=\$3)(ncpu=\$4)(scpu=\$5)(wcpu=\$6)(icpu=\$8); else if (\$2 ~ /^eth[0-9]+/ )(eth_r+=\$5)(eth_t+=\$6)(eth_rp+=\$3)(eth_tp+=\$4); else if (\$2 ~ /^ib[0-9]+/ )(ib_r+=\$5)(ib_t+=\$6); else if($2 ~ /^[0-9]+$/ ) (runq=\$2) } END { printf(\"%5.2f %5.2f %5.2f %5.2f %d %d %f 0 %10.2f %d %10.2f %d %10.2f %10.2f\n\", ucpu, scpu, wcpu, icpu, runq, ncpu,memu, eth_r/1024, eth_rp, eth_t/1024, eth_tp, ib_r/1024, ib_t/1024) }' 2>/dev/null 3>/dev/null`" >> /tmp/sad_$t.tmp &
   else
    echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} sar -u -q -n DEV $1 1|grep Average | awk 'BEGIN {ucpu=0;scpu=0;memu=0;swapu=0;icpu=0;eth_r=0.0;eth_t=0.0;ib_r=0.0;ib_t=0.0;eth_rp=0.0;eth_tp=0.0;runq=0.0} {if (length( \$2 + \$3 ) == 8 || length( \$2 + \$3 ) == 9)  (memu=\$4) (swapu=\$7); else if (\$2==\"all\") (ucpu=\$3)(ncpu=\$4)(scpu=\$5)(wcpu=\$6)(icpu=\$8); else if (\$2==\"bondeth0\")(eth_r=\$5)(eth_t=\$6)(eth_rp=\$3)(eth_tp=\$4); else if (\$2==\"eth0\"||\$2==\"vmeth0\")(eth0_r=\$5)(eth0_t=\$6)(eth0_rp=\$3)(eth0_tp=\$4); else if (\$2==\"eth3\")(eth3_r=\$5)(eth3_t=\$6)(eth3_rp=\$3)(eth3_tp=\$4); else if (\$2==\"bondeth1\")(eth10_r=\$5)(eth10_t=\$6)(eth10_rp=\$3)(eth10_tp=\$4); else if (\$2==\"ib0\"||\$2==\"ib1\"||\$2==\"bond1\"||/bondib/)(ib_r+=\$5)(ib_t+=\$6); else if (\$2==\"lo\"||\$2==\"IFACE\"||/bond/||/eth/)(x_r+=\$5); else (runq=\$2) } END { print ucpu \" \" scpu \" \" wcpu \" \" icpu \" \" runq \" \" ncpu \" \" memu \" \" 0 \" \" (eth_r+eth0_r+eth3_r+eth10_r)/1024/1024 \" \" (eth_rp+eth0_rp+eth3_rp+eth10_rp) \" \" (eth_t+eth0_t+eth3_t+eth10_t)/1024/1024 \" \" (eth_tp+eth0_tp+eth3_tp+eth10_tp) \" \" ib_r/1024/1024 \" \" ib_t/1024/1024 }' 2>/dev/null 3>/dev/null`" >> /tmp/sad_$t.tmp &
   fi
  fi
  arr_i=`expr $arr_i + 1`
 done < $v_dbs_group_file

arr_i=1
cp /dev/null /tmp/sac_$t.tmp
while read line
do
 dsk_dev=${sa_dsk[$arr_i]}
 model_name=${sa_model[$arr_i]}
 flash_cnt=${sa_flash[$arr_i]}
 hard_cnt=${sa_hard[$arr_i]}
 m2v1=${sa_m2v1[$arr_i]}
 m2v2=${sa_m2v2[$arr_i]}
 if [ "$dsk_dev" = "/dev/sdq" ] || [ "$dsk_dev" = "" ] ; then
   echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sar -pud $1 1 | grep Average |$AWK 'BEGIN {rsum1 = 0;rsum2 = 0;wsum1 = 0;wsum2 = 0;wait1 = 0;wait2 = 0;cnt1=0;cnt2=0;rtime1=0;rtime2=0;max_w1 = 0;tps1 = 0;tps2 = 0} {if (\$2==\"sdq\"||\$2==\"sdr\"||\$2==\"sds\"||\$2==\"sdt\"||\$2==\"sdu\"||\$2==\"sdv\"||\$2==\"sdw\"||\$2==\"sdx\"||\$2==\"sdy\"||\$2==\"sdz\"||\$2==\"sdaa\"||\$2==\"sdab\" ) (tps1 +=\$3) (rsum1 +=\$4 ) (wsum1 +=\$5 ) (svctm1 +=\$9) (wait1 +=\$10) (max_w1=(\$10>max_w1)?\$10:max_w1) (cnt1 +=1) (rtime1 +=\$8); else if (/nvme/||\$2==\"sda\"||\$2==\"sdb\"||\$2==\"sdc\"||\$2==\"sdd\"||\$2==\"sde\"||\$2==\"sdf\"||\$2==\"sdg\"||\$2==\"sdh\"||\$2==\"sdi\"||\$2==\"sdj\"||\$2==\"sdk\"||\$2==\"sdl\"||\$2==\"sdm\"||\$2==\"sdn\"||\$2==\"sdo\"||\$2==\"sdp\" ) (tps2 +=\$3) (rsum2 +=\$4) (wsum2 +=\$5) (svctm2 +=\$9) (wait2 +=\$10) (max_w2=(\$10>max_w2)?\$10:max_w2) (cnt2 +=1) (rtime2 +=\$8); else if (\$2==\"all\") (ucpu = \$3) (wcpu = \$6) (icpu =\$8) }  END { if(cnt1 == 0)(cnt1=1); if(cnt2 == 0)(cnt2=1); printf(\"IO %8.2f %8.2f %8.2f %8.2f %8.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.3f %6.3f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f\n\", (rsum1+rsum2+wsum1+wsum2)*512/1024/1024, rsum1*512/1024/1024, wsum1*512/1024/1024, rsum2*512/1024/1024, wsum2*512/1024/1024, ucpu, wcpu, icpu, wait1/cnt1, wait2/cnt2, rtime1/cnt1, rtime2/cnt2, max_w1, max_w2, tps1, tps2, svctm1/cnt1, svctm2/cnt2) }' 2>/dev/null 3>/dev/null`" >> /tmp/sac_$t.tmp &
 else
  if [ "$model_name" = "X7-2L" ] ; then
   # X7 disk : sdc~sdn
   echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sar -pud $1 1 | grep Average |$AWK 'BEGIN {rsum1 = 0;rsum2 = 0;wsum1 = 0;wsum2 = 0;wait1 = 0;wait2 = 0;cnt1=0;cnt2=0;rtime1=0;rtime2=0;max_w1 = 0;tps1 = 0;tps2 = 0} {if (\$2==\"sdm\"||\$2==\"sdn\"||\$2==\"sdc\"||\$2==\"sdd\"||\$2==\"sde\"||\$2==\"sdf\"||\$2==\"sdg\"||\$2==\"sdh\"||\$2==\"sdi\"||\$2==\"sdj\"||\$2==\"sdk\"||\$2==\"sdl\" ) (tps1 +=\$3) (rsum1 +=\$4 ) (wsum1 +=\$5 ) (svctm1 +=\$9) (wait1 +=\$10) (max_w1=(\$10>max_w1)?\$10:max_w1) (cnt1 +=1) (rtime1 +=\$8); else if (/nvme/) (tps2 +=\$3) (rsum2 +=\$4) (wsum2 +=\$5) (svctm2 +=\$9) (wait2 +=\$10) (max_w2=(\$10>max_w2)?\$10:max_w2) (cnt2 +=1) (rtime2 +=\$8); else if (\$2==\"all\") (ucpu = \$3) (wcpu = \$6) (icpu =\$8) }  END { if(cnt1 == 0)(cnt1=1); if(cnt2 == 0)(cnt2=1); printf(\"IO %8.2f %8.2f %8.2f %8.2f %8.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.3f %6.3f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f\n\", (rsum1+rsum2+wsum1+wsum2)*512/1024/1024, rsum1*512/1024/1024, wsum1*512/1024/1024, rsum2*512/1024/1024, wsum2*512/1024/1024, ucpu, wcpu, icpu, wait1/cnt1, wait2/cnt2, rtime1/cnt1, rtime2/cnt2, max_w1, max_w2, tps1, tps2, svctm1/cnt1, svctm2/cnt2) }' 2>/dev/null 3>/dev/null`" >> /tmp/sac_$t.tmp &
  elif [ "$dsk_dev" = "/dev/sda" ] && [ "$model_name" = "X8-2L" ] ; then
   #echo $model_name
   # X8 disk : sda~sdl
   echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sar -pud $1 1 | grep Average |$AWK -v v1=$m2v1 -v v2=$m2v2 -v hcnt=$hard_cnt -v fcnt=$flash_cnt 'BEGIN {rsum1 = 0;rsum2 = 0;wsum1 = 0;wsum2 = 0;wait1 = 0;wait2 = 0;cnt1=0;cnt2=0;rtime1=0;rtime2=0;max_w1 = 0;tps1 = 0;tps2 = 0;iou=512/1024/1024} {if (/sd/ && \$2!=v1 && \$2!=v2 ) (tps1 +=\$3) (rsum1 +=\$4 ) (wsum1 +=\$5 ) (svctm1 +=\$9) (wait1 +=\$10) (max_w1=(\$10>max_w1)?\$10:max_w1) (cnt1 +=1) (rtime1 +=\$8); else if (/nvme/) (tps2 +=\$3) (rsum2 +=\$4) (wsum2 +=\$5) (svctm2 +=\$9) (wait2 +=\$10) (max_w2=(\$10>max_w2)?\$10:max_w2) (cnt2 +=1) (rtime2 +=\$8); else if (\$2==\"all\") (ucpu = \$3) (wcpu = \$6) (icpu =\$8) }  END { printf(\"IO %8.2f %8.2f %8.2f %8.2f %8.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.3f %6.3f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f\n\", (rsum1+rsum2+wsum1+wsum2)*iou/1024/1024, rsum1*iou, wsum1*iou, rsum2*iou, wsum2*iou, ucpu, wcpu, icpu, wait1/hcnt, wait2/fcnt, rtime1/hcnt, rtime2/fcnt, max_w1, max_w2, tps1, tps2, svctm1/hcnt, svctm2/fcnt) }' 2>/dev/null 3>/dev/null`" >> /tmp/sac_$t.tmp &
  elif [ "$model_name" = "X5-2L" ] || [ "$model_name" = "X6-2L" ] ; then
   echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sar -pud $1 1 | grep Average |$AWK 'BEGIN {rsum1 = 0;rsum2 = 0;wsum1 = 0;wsum2 = 0;wait1 = 0;wait2 = 0;cnt1=0;cnt2=0;rtime1=0;rtime2=0;max_w1 = 0;tps1 = 0;tps2 = 0} {if (/sd/ && \$2!=\"sdm\") (tps1 +=\$3) (rsum1 +=\$4 ) (wsum1 +=\$5 ) (svctm1 +=\$9) (wait1 +=\$10) (max_w1=(\$10>max_w1)?\$10:max_w1) (cnt1 +=1) (rtime1 +=\$8); else if (/nvme/) (tps2 +=\$3) (rsum2 +=\$4) (wsum2 +=\$5) (svctm2 +=\$9) (wait2 +=\$10) (max_w2=(\$10>max_w2)?\$10:max_w2) (cnt2 +=1) (rtime2 +=\$8); else if (\$2==\"all\") (ucpu = \$3) (wcpu = \$6) (icpu =\$8) }  END { if(cnt1 == 0)(cnt1=1); if(cnt2 == 0)(cnt2=1); printf(\"IO %8.2f %8.2f %8.2f %8.2f %8.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.3f %6.3f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f\n\", (rsum1+rsum2+wsum1+wsum2)*512/1024/1024, rsum1*512/1024/1024, wsum1*512/1024/1024, rsum2*512/1024/1024, wsum2*512/1024/1024, ucpu, wcpu, icpu, wait1/cnt1, wait2/cnt2, rtime1/cnt1, rtime2/cnt2, max_w1, max_w2, tps1, tps2, svctm1/cnt1, svctm2/cnt2) }' 2>/dev/null 3>/dev/null`" >> /tmp/sac_$t.tmp &
  else
   echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sar -pud $1 1 | grep Average |$AWK 'BEGIN {rsum1 = 0;rsum2 = 0;wsum1 = 0;wsum2 = 0;wait1 = 0;wait2 = 0;cnt1=0;cnt2=0;rtime1=0;rtime2=0;max_w1 = 0;tps1 = 0;tps2 = 0} {if (\$2==\"sda\"||\$2==\"sdb\"||\$2==\"sdc\"||\$2==\"sdd\"||\$2==\"sde\"||\$2==\"sdf\"||\$2==\"sdg\"||\$2==\"sdh\"||\$2==\"sdi\"||\$2==\"sdj\"||\$2==\"sdk\"||\$2==\"sdl\" ) (tps1 +=\$3) (rsum1 +=\$4 ) (wsum1 +=\$5 ) (svctm1 +=\$9) (wait1 +=\$10) (max_w1=(\$10>max_w1)?\$10:max_w1) (cnt1 +=1) (rtime1 +=\$8); else if (/nvme/||\$2==\"sdm\"||\$2==\"sdn\"||\$2==\"sdo\"||\$2==\"sdp\"||\$2==\"sdq\"||\$2==\"sdr\"||\$2==\"sds\"||\$2==\"sdt\"||\$2==\"sdu\"||\$2==\"sdv\"||\$2==\"sdw\"||\$2==\"sdx\"||\$2==\"sdy\"||\$2==\"sdz\"||\$2==\"sdaa\"||\$2==\"sdab\" ) (tps2 +=\$3) (rsum2 +=\$4) (wsum2 +=\$5) (svctm2 +=\$9) (wait2 +=\$10) (max_w2=(\$10>max_w2)?\$10:max_w2) (cnt2 +=1) (rtime2 +=\$8); else if (\$2==\"all\") (ucpu = \$3) (wcpu = \$6) (icpu =\$8) }  END { if(cnt1 == 0)(cnt1=1); if(cnt2 == 0)(cnt2=1); printf(\"IO %8.2f %8.2f %8.2f %8.2f %8.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.3f %6.3f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f\n\", (rsum1+rsum2+wsum1+wsum2)*512/1024/1024, rsum1*512/1024/1024, wsum1*512/1024/1024, rsum2*512/1024/1024, wsum2*512/1024/1024, ucpu, wcpu, icpu, wait1/cnt1, wait2/cnt2, rtime1/cnt1, rtime2/cnt2, max_w1, max_w2, tps1, tps2, svctm1/cnt1, svctm2/cnt2) }' 2>/dev/null 3>/dev/null`" >> /tmp/sac_$t.tmp &
  fi
 fi
 arr_i=`expr $arr_i + 1`
done < $v_cell_group_file

if [ $dsk_f -ne "0" ]; then
 cp /dev/null /tmp/cel2_$t.tmp
 while read line
 do
  echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} /opt/oracle/cell/cellsrv/bin/cellcli -e \"list metriccurrent where metricType = \'Rate\' and objectType = \'CELLDISK\'\" | grep -v FD | grep -v min | sed s/,//g | awk 'BEGIN {sr=0;lr=0} {if (\$1==\"CD_IO_RQ_R_SM_SEC\") (rsc+=\$3); else if (\$1==\"CD_IO_RQ_W_SM_SEC\") (wsc+=\$3); else if (\$1==\"CD_IO_RQ_R_LG_SEC\") (rlc+=\$3); else if (\$1==\"CD_IO_RQ_W_LG_SEC\") (wlc+=\$3); else if (\$1==\"CD_IO_BY_R_SM_SEC\") (rsb+=\$3); else if (\$1==\"CD_IO_BY_W_SM_SEC\") (wsb+=\$3); else if (\$1==\"CD_IO_BY_R_LG_SEC\") (rlb+=\$3); else if (\$1==\"CD_IO_BY_W_LG_SEC\") (wlb+=\$3); else if (\$1==\"CD_IO_TM_R_SM_RQ\") (rst+=\$3) (cnt+=1); else if (\$1==\"CD_IO_TM_W_SM_RQ\") (wst+=\$3); else if (\$1==\"CD_IO_TM_R_LG_RQ\") (rlt+=\$3); else if (\$1==\"CD_IO_TM_W_LG_RQ\") (wlt+=\$3) } END { printf(\"%7.1f %6.1f %7.1f %6.1f %6.1f %5.1f %5.1f %5.1f %5.1f %5.1f %6.1f %6.1f %7.1f %6.1f \n\", rsc, wsc, rlc, wlc, rsc+wsc+rlc+wlc, rsb, wsb, rlb, wlb, rsb+wsb+rlb+wlb, rst/cnt, wst/cnt, rlt/cnt, wlt/cnt ) }'`" >> /tmp/cel2_$t.tmp &
 done < $v_cell_group_file

 cp /dev/null /tmp/cel3_$t.tmp
 while read line
 do
  echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} /opt/oracle/cell/cellsrv/bin/cellcli -e \"list metriccurrent where metricType = \'Rate\' and objectType = \'CELLDISK\'\" | grep FD_ | grep -v min | sed s/,//g | awk 'BEGIN {sr=0;lr=0} {if (\$1==\"CD_IO_RQ_R_SM_SEC\") (rsc+=\$3); else if (\$1==\"CD_IO_RQ_W_SM_SEC\") (wsc+=\$3); else if (\$1==\"CD_IO_RQ_R_LG_SEC\") (rlc+=\$3); else if (\$1==\"CD_IO_RQ_W_LG_SEC\") (wlc+=\$3); else if (\$1==\"CD_IO_BY_R_SM_SEC\") (rsb+=\$3); else if (\$1==\"CD_IO_BY_W_SM_SEC\") (wsb+=\$3); else if (\$1==\"CD_IO_BY_R_LG_SEC\") (rlb+=\$3); else if (\$1==\"CD_IO_BY_W_LG_SEC\") (wlb+=\$3); else if (\$1==\"CD_IO_TM_R_SM_RQ\") (rst+=\$3) (cnt+=1); else if (\$1==\"CD_IO_TM_W_SM_RQ\") (wst+=\$3); else if (\$1==\"CD_IO_TM_R_LG_RQ\") (rlt+=\$3); else if (\$1==\"CD_IO_TM_W_LG_RQ\") (wlt+=\$3)  } END { printf(\"%7.1f %6.1f %7.1f %6.1f %6.1f %5.1f %5.1f %5.1f %5.1f %5.1f %6.1f %6.1f %7.1f %6.1f \n\", rsc, wsc, rlc, wlc, rsc+wsc+rlc+wlc, rsb, wsb, rlb, wlb, rsb+wsb+rlb+wlb, rst/cnt, wst/cnt, rlt/cnt, wlt/cnt ) }'`" >> /tmp/cel3_$t.tmp &
 done < $v_cell_group_file
fi

arr_i=1
cp /dev/null /tmp/sag_$t.tmp
cp /dev/null /tmp/sai_$t.tmp
cp /dev/null /tmp/sap_$t.tmp
cp /dev/null /tmp/sap2_$t.tmp
cp /dev/null /tmp/sah_$t.tmp
while read line
do

  if [ "$user_name" == "root" ] ; then
    echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sh ~/sa_exec_${line}.sh`" >> /tmp/sah_$t.tmp &
  fi
  if [ $roce_y -eq 1 ] ; then
    echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sh ~/sa_pmem2_${line}.sh`" >> /tmp/sap2_$t.tmp &
    if [ $pmem_f -eq 1 ] ; then
      echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sh ~/sa_pmem_${line}.sh`" >> /tmp/sap_$t.tmp &
    fi
  fi
done < $v_cell_group_file

while read line
do
  echo ${line}: "`ssh ${line} ${SSH_DB_OPTION} /usr/bin/rds-info -c 2>/dev/null | grep user | awk 'BEGIN {rx=0;tx=0} { if ($1 == "copy_to_user")(rx=$2); else if ($1=="copy_from_user")(tx=$2)} END { printf(\"%s %s\", rx, tx) }' 2>/dev/null 3>/dev/null`" >> /tmp/sai_$t.tmp &
done < $v_dbs_group_file

 arr_i=1
 if [ $ib_f -eq 0 ]; then
  if [ "$user_name" == "root" ] ; then
    while read line
    do
     os_v=${sa_osv_db[$arr_i]}
     echo ${line}: "`ssh ${line} ${SSH_CELL_OPTION} sh ~/sa_exec_${line}.sh`" >> /tmp/sah_$t.tmp &
    done < $v_dbs_group_file
  fi
 fi

wait

if [ $debug_f -eq 1 ] ; then
   echo "=> Sar basic info CPU Memory Network"
   cat /tmp/sad_$t.tmp
   if [ "$os_name" = "SunOS" ]; then
      echo "=> DB solaris Network "
      cat /tmp/sadd_$t.tmp
   fi
   echo "=> Cell IO sac"
   cat /tmp/sac_$t.tmp
   echo "=> Network sag"
   cat /tmp/sag_$t.tmp
   echo "====> Infiniband DB sai"
   cat /tmp/sai_$t.tmp
   echo "====> Infiniband DB sah"
   cat /tmp/sah_$t.tmp
fi

#cat /tmp/sag_$t.tmp

finish_date=`date +%H:%M:%S`
h1=`echo $issue_date | cut -b1-2`
m1=`echo $issue_date | cut -b4-5`
s1=`echo $issue_date | cut -b7-8`
h2=`echo $finish_date | cut -b1-2`
m2=`echo $finish_date | cut -b4-5`
s2=`echo $finish_date | cut -b7-8`
hg=`expr $h2 - $h1`
mg=`expr $m2 - $m1`
sg=`expr $s2 - $s1`
stop_time=`date +%s%N`
dur=`expr  \( $stop_time - $start_time \) / 1000000`
#dur=`expr $hg \* 3600 + $mg \* 60 + $sg`

if [ $dur -lt 0 ] ; then
  dur=`expr 3600 + $mg \* 60 + $sg`
fi

cp /tmp/sac_$t.tmp /tmp/sa_debug_$t.tmp
cp /dev/null /tmp/sac1_$t.tmp
while read line
do
  #rx=`grep ${line} /tmp/sag_$t.tmp | awk '{ print $2 }'`
  #tx=`grep ${line} /tmp/sag_$t.tmp | awk '{ print $3 }'`
  #rx_b=`grep ${line} /tmp/sag_org_$t.tmp | awk '{ print $2 }'`
  #tx_b=`grep ${line} /tmp/sag_org_$t.tmp | awk '{ print $3 }'`
  #rx_d=`expr \( $rx - $rx_b \) / $dur`
  #tx_d=`expr \( $tx - $tx_b \) / $dur`

  #echo expr \( $rp - $rp_b \) / $dur
  #echo expr \( $tp - $tp_b \) / $dur

  if [ $ib_f -eq 0 ] && [ $start_flag -eq 1 ] ; then
    rb=`grep ${line} /tmp/sah_$t.tmp | awk 'BEGIN {tot=0} {tot+=$2} END { print tot }'`
    tb=`grep ${line} /tmp/sah_$t.tmp | awk 'BEGIN {tot=0} {tot+=$3} END { print tot }'`
  else
    rb=0
    tb=0
  fi 

  if [ $roce_y -eq 1 ] ; then
    rp2=`grep ${line} /tmp/sap2_$t.tmp | awk '{ print $2 }'`
    tp2=`grep ${line} /tmp/sap2_$t.tmp | awk '{ print $3 }'`
    mp2=`grep ${line} /tmp/sap2_$t.tmp | awk '{ print $4 }'`
    rx2=`grep ${line} /tmp/sap2_$t.tmp | awk '{ print $5 }'`
    tx2=`grep ${line} /tmp/sap2_$t.tmp | awk '{ print $6 }'`
    if [ $pmem_f -eq 1 ] ; then
      rp=`grep ${line} /tmp/sap_$t.tmp | awk '{ print $2 }'`
      tp=`grep ${line} /tmp/sap_$t.tmp | awk '{ print $3 }'`
      rp_b=`grep ${line} /tmp/sap_org_$t.tmp | awk '{ print $2 }'`
      tp_b=`grep ${line} /tmp/sap_org_$t.tmp | awk '{ print $3 }'`
      rp_d=`expr \( $rp - $rp_b \) / $dur \* 1000 `
      tp_d=`expr \( $tp - $tp_b \) / $dur \* 1000 `
      #echo rx_d : $rx_d tx_d : $tx_d  rp_d : $rp_d  tp_d : $tp_d rp2 : $rp2 tp2 : $tp2 
      echo `grep ${line} /tmp/sac_$t.tmp` $rb $tb $rp2 $tp2 $mp2 $rp_d $tp_d >> /tmp/sac1_$t.tmp
    else
      echo `grep ${line} /tmp/sac_$t.tmp` $rb $tb $rp2 $tp2 $mp2 >> /tmp/sac1_$t.tmp
    fi
  else
    rb=`expr $rb \* 4 / $dur \* 1000`
    tb=`expr $tb \* 4 / $dur \* 1000`
    echo `grep ${line} /tmp/sac_$t.tmp` $rb $tb >> /tmp/sac1_$t.tmp
  fi
done < $v_cell_group_file

cp /dev/null /tmp/sad1_$t.tmp
#cat /tmp/sah_$t.tmp
while read line
do
  #rx=`grep ${line} /tmp/sag_$t.tmp | awk '{ print $2 }'`
  #tx=`grep ${line} /tmp/sag_$t.tmp | awk '{ print $3 }'`
  #rx_b=`grep ${line} /tmp/sag_org_$t.tmp | awk '{ print $2 }'`
  #tx_b=`grep ${line} /tmp/sag_org_$t.tmp | awk '{ print $3 }'`
  #echo rx $rx tx $tx rx_b $rx_b tx_b $tx_b
  #rx_d=`expr \( $rx - $rx_b \) / $dur`
  #tx_d=`expr \( $tx - $tx_b \) / $dur`

  ri=`grep ${line} /tmp/sai_$t.tmp | awk '{ print $2 }'`
  ti=`grep ${line} /tmp/sai_$t.tmp | awk '{ print $3 }'`
  ri_b=`grep ${line} /tmp/sai_org_$t.tmp | awk '{ print $2 }'`
  ti_b=`grep ${line} /tmp/sai_org_$t.tmp | awk '{ print $3 }'`
  #echo ri $ri ti $ti ri_b $ri_b ti_b $ti_b
  ri_d=`expr \( $ri - $ri_b \) / 4 / $dur \* 1000`
  ti_d=`expr \( $ti - $ti_b \) / 4 / $dur \* 1000`

  if [ $debug_f -eq 1 ] ; then
    echo $line rx $rx tx $tx rx_b $ri_b tx_b $ti_b
    echo $line tx_d : `expr $ti_d` ri_d : `expr $ri_d`
  fi

  if [ $ib_f -eq 0 ] && [ $start_flag -eq 1 ] ; then
    rb=`grep ${line} /tmp/sah_$t.tmp | awk 'BEGIN {tot=0} {tot+=$2} END { print tot }'`
    tb=`grep ${line} /tmp/sah_$t.tmp | awk 'BEGIN {tot=0} {tot+=$3} END { print tot }'`
  else
    rb=0
    tb=0
  fi

  if [ "$os_name" = "SunOS" ]; then
    #cat /tmp/sadd_$t.tmp
    eth_r=`grep ${line} /tmp/sadd_$t.tmp | awk '{ print $2/1024 }'`
    eth_t=`grep ${line} /tmp/sadd_$t.tmp | awk '{ print $4/1024 }'`
    eth_rp=`grep ${line} /tmp/sadd_$t.tmp | awk '{ print $3 }'`
    eth_tp=`grep ${line} /tmp/sadd_$t.tmp | awk '{ print $5 }'`
    #echo Fisrt : eth_r $eth_r eth_rp $eth_rp eth_t $eth_t eth_tp $eth_tp 
    eth_r=`echo $eth_r $1 | awk '{print $1/$2}'`
    eth_t=`echo $eth_t $1 | awk '{print $1/$2}'`
    eth_rp=`echo $eth_rp $1 | awk '{print $1/$2}'`
    eth_tp=`echo $eth_tp $1 | awk '{print $1/$2}'`
    #echo Second : eth_r $eth_r eth_rp $eth_rp eth_t $eth_t eth_tp $eth_tp 
    echo `grep ${line} /tmp/sad_$t.tmp` "$eth_r $eth_rp $eth_t $eth_tp $rx_d $tx_d $rb $tb" >> /tmp/sad1_$t.tmp
  else
    if [ $roce_y -eq 1 ] ; then
      #echo `grep ${line} /tmp/sad_$t.tmp` $ri_d $ti_d $rx_d $tx_d >> /tmp/sad1_$t.tmp
      echo `grep ${line} /tmp/sad_$t.tmp` $ri_d $ti_d $rb $tb >> /tmp/sad1_$t.tmp
    else
      rb=`expr $rb \* 4 / $dur \* 1000`
      tb=`expr $tb \* 4 / $dur \* 1000`
      echo `grep ${line} /tmp/sad_$t.tmp` $ri_d $ti_d $rb $tb >> /tmp/sad1_$t.tmp
    fi
  fi
  if [ $debug_f -eq 1 ] ; then
     echo $line rb : $rb  tb : $tb 
  fi
done < $v_dbs_group_file

start_flag=1

cp /dev/null /tmp/sad2_$t.tmp

while read line
do
 if [ "$os_name" = "SunOS" ]; then
  #totmem=`ssh ${line} ${SSH_DB_OPTION} prtconf |grep Mem |awk '{ print $3/1024 }'`
  totmem=`grep ${line} /tmp/sadd1_$t.tmp | awk '{ print $2 }'`
  # paesize solaris sparce : 8k  x86 : 4k
  if [ "$os_type" == "X86" ]; then
     freemem=`grep ${line} /tmp/sad1_$t.tmp |awk '{ print $8 * 4 }'`
  else
     freemem=`grep ${line} /tmp/sad1_$t.tmp |awk '{ print $8 * 8 }'`
  fi
  echo tot: $totmem , free : $freemem
  real_pct=`echo $totmem $freemem | awk '{ print ($1 - $2) / $1 * 100 }` 
  #swap_pct=`ssh ${line} ${SSH_DB_OPTION} swap -s -h | awk '{ print $8 $10 }'|awk -F"G" '{print $1 / ($1 + $2) * 100 }'`
  #swap_size=`ssh ${line} ${SSH_DB_OPTION} swap -s -h | awk '{ print $8 $10 }'|awk -F"G" '{print $1 + $2 }'`
  swap_pct=`grep ${line} /tmp/sadd2_$t.tmp | awk '{print $2}' | awk -F"G" '{print $1 / ($1 + $2) * 100 }'`
  swap_size=`grep ${line} /tmp/sadd2_$t.tmp | awk '{print $2}' | awk -F"G" '{print $1 + $2 }'`
  echo real_pct: $real_pct
  echo swap_pct: $swap_pct
  echo `grep ${line} /tmp/sad1_$t.tmp` $real_pct $swap_pct $swap_size >> /tmp/sad2_$t.tmp
 else
  argmem=`ssh ${line} ${SSH_DB_OPTION} "egrep \"MemTotal|MemFree|Inactive:|SwapTotal:|SwapFree:\" /proc/meminfo | awk '{print \\$2}'"`
  #echo MEM_PARAM : $argmem 
  totmem=`echo $argmem | cut -d" " -f1`
  freemem=`echo $argmem | cut -d" " -f2`
  inamem=`echo $argmem | cut -d" " -f3`
  swap_size=`echo $argmem | cut -d" " -f4`
  swap_usage=`echo $argmem | cut -d" " -f5`
  #echo TOT : $totmem FREE : $freemem INA : $inamem 
  mem_pct=`expr \( $totmem - $freemem \) \* 1000 / $totmem` 
  real_pct=`expr \( $totmem - $freemem - $inamem \) \* 1000 / $totmem` 
  swap_pct=`expr \( $swap_size - $swap_usage \) \* 1000 / $swap_size` 
  if [ $ovm_f -eq 1 ] ; then
    argcpu=`ssh ${line} ${SSH_DB_OPTION} "grep \"processor\" /proc/cpuinfo | wc -l "`
    echo `grep ${line} /tmp/sad1_$t.tmp` $mem_pct $real_pct $swap_pct $argcpu $totmem >> /tmp/sad2_$t.tmp
  else
    echo `grep ${line} /tmp/sad1_$t.tmp` $mem_pct $real_pct $swap_pct >> /tmp/sad2_$t.tmp
  fi
 fi
done < $v_dbs_group_file

cp /tmp/sag_$t.tmp /tmp/sag_org_$t.tmp
cp /tmp/sai_$t.tmp /tmp/sai_org_$t.tmp
cp /tmp/sap_$t.tmp /tmp/sap_org_$t.tmp

#cat /tmp/sad_$t.tmp

if [ $debug_f -eq 1 ] ; then
   echo " => Infinband DB"
   cat /tmp/sac1_$t.tmp
   echo " => network DB"
   cat /tmp/sad1_$t.tmp
   echo " => memory DB"
   cat /tmp/sad2_$t.tmp
fi

echo "*" `date` $i "(Max:$2, interval:$1 sec) Start : $issue_date (`echo $dur | awk '{printf("%4.1f", $1/1000)}'` sec) version : $version " > /tmp/sa1_$t.tmp
if [ $roce_y -eq 1 ]; then
  echo -e "========== DBMS Server ========================================================================================================="  >> /tmp/sa1_$t.tmp
else
  echo "========== DBMS Server ====================================================================================================="  >> /tmp/sa1_$t.tmp
fi
echo $spa1 | sed s/Z/" "/g | awk '{ printf("* Node%s:", $0)}' >> /tmp/sa1_$t.tmp
if [ "$os_name" = "SunOS" ]; then
  echo "         CPU Usage (%)         |  Memory(%) | swap |    TCP MB/sec & packet count   | infini(RDS:MB, Total:MB)" >> /tmp/sa1_$t.tmp
elif [ $roce_y -eq 1 ]; then
  echo "       CPU Usage (%)      |    Memory(%)  |Ethernet MB/sec & packet cnt|  ROCE(TCP:MB, RDS:MB, Total:MB)" >> /tmp/sa1_$t.tmp
elif [ $ovm_f = 1 ]; then
  echo "         CPU Usage (%)       |      Memory(%)     |  TCP MB/sec & packet count | infini(TCP:MB, RDS:MB, Total:MB)" >> /tmp/sa1_$t.tmp
elif [ $ext_f = 0 ]; then
  echo "       CPU Usage (%)      |    Memory(%)  |Ethernet MB/sec & packet cnt| infini(TCP:MB, RDS:MB, Total:MB)" >> /tmp/sa1_$t.tmp
else
  echo "         CPU Usage (%)         |  Memory(%)   |    TCP MB/sec & packet count   | infini(RDS:MB, Total:MB)" >> /tmp/sa1_$t.tmp
fi

echo $spa1 | sed s/Z/" "/g | awk '{ printf("* Node%s:", $0)}' >> /tmp/sa1_$t.tmp
if [ "$os_name" = "SunOS" ]; then
  printf " user nice  sys wait  idle runq|  puse  suse| sizeG|rv size & packet|tr size & packt| rds_rv rds_tr " >> /tmp/sa1_$t.tmp
elif [ $ovm_f = 1 ]; then
  printf " user sys wait  idle runq cnt| used real swap size|rv size&packet|tr size&packt| tcp_rv tcp_tr rds_rv rds_tr " >> /tmp/sa1_$t.tmp
elif [ $ext_f = 0 ]; then
  printf " user  sys wait  idle runq| used real swap|rv size&packet|tr size&packt| tcp_rv tcp_tr rds_rv rds_tr " >> /tmp/sa1_$t.tmp
else
  printf " user nice  sys wait  idle runq| used real swap|rv size&packet|tr size&packt| tcp_rv tcp_tr rds_rv rds_tr " >> /tmp/sa1_$t.tmp
fi

if [ $ib_f -eq 0 ] || [ $roce_y -eq 1 ] ; then
  echo 1 | awk '{ printf(" tot_rv  tot_tr\n") }' >> /tmp/sa1_$t.tmp
else
  echo 1 | awk '{ printf("#root only val\n") }' >> /tmp/sa1_$t.tmp
fi

#cat /tmp/sad_$t.tmp >> /tmp/sa1_$t.tmp
sort /tmp/sad2_$t.tmp >> /tmp/sa1_$t.tmp

if [ "$prod" == "xl" ]; then
 echo "========== ZFS Disk Server =====================================================================================================" > /tmp/saz_$t.tmp
 echo $spa2 | sed s/Z/" "/g | awk '{ printf("* Node%s:   CPU |  Disk  | Network | NFSv3 | NFSv4 |      Memory\n", $0)}' >> /tmp/saz_$t.tmp
 echo $spa2 | sed s/Z/" "/g | awk '{ printf("      %s: Uti(%)| ops/sec|bytes/sec|ops/sec|ops/sec|   Cache   Unused \n", $0)}' >> /tmp/saz_$t.tmp
 sort /tmp/zfs_$t.tmp >> /tmp/saz_$t.tmp
else
 if [ $roce_y -eq 1 ]; then
   echo "========== Cell Disk Server ==============================================================================================================================" >> /tmp/sa1_$t.tmp
   if [ $pmem_f -eq 1 ]; then
   echo $spa2 | sed s/Z/" "/g | awk '{ printf("* Node%s: Total |                Disk I/O                |              Flash I/O                 | CPU |   ROCE(MByte)   |    PMEM_DIM(MByte)\n", $0)}' >> /tmp/sa1_$t.tmp
   else
   echo $spa2 | sed s/Z/" "/g | awk '{ printf("* Node%s: Total |                Disk I/O                |              Flash I/O                 | CPU |   ROCE(MByte)   |    PMEM_cellstat(MByte)\n", $0)}' >> /tmp/sa1_$t.tmp
   fi
 else
   echo "========== Cell Disk Server ================================================================================================" >> /tmp/sa1_$t.tmp
   echo $spa2 | sed s/Z/" "/g | awk '{ printf("* Node%s: Total |                Disk I/O                |              Flash I/O                 | CPU |  infini(MByte)\n", $0)}' >> /tmp/sa1_$t.tmp

 fi
 echo $spa2 | sed s/Z/" "/g | awk '{ printf("* MB/s%s:   Sum |   Read  Write  Avg%", $0)}' >> /tmp/sa1_$t.tmp
 if [ $roce_y -eq 1 ]; then
   echo "  Max%     tps svctm|   Read  Write  Avg%  Max%     tps svctm|  pct| receive transfer|     Read   Write ReadMiss" >> /tmp/sa1_$t.tmp
 else
   echo "   Max%    tps svctm|   Read  Write  Avg%  Max%     tps svctm|  pct| receive transfer" >> /tmp/sa1_$t.tmp
 fi
 sort /tmp/sac1_$t.tmp >> /tmp/sa1_$t.tmp
fi

#cat /tmp/sa1_$t.tmp
if [ "$os_name" = "SunOS" ]; then
  #echo size SUNOS ${size1t}
  $AWK -v size1=${size1t} '{ if ($1 == "==========" || $1 == "*") print $0; \
  else if ($2 == "") (a=1)  ; \
  else if ($2 != "IO") printf("%-*s %4.1f %4.1f %4.1f %4.1f%6.1f%5.0f|%6.1f%6.1f%7.1f|%8.1f%8.0f%8.1f%8.0f|%7.1f%7.1f%8.1f%8.1f\n", \
                       size1, $1, $2,  $7,   $3,   $4,  $5,  $6,   $18, $19, $20,  $10/1024, $11, $12/1024, $13,  $14/1024/1024, $15/1024/1024, $16/1024/1024, $17/1024/1024  ); \
  else printf("%s%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%8.1f\n", \
             $1, $3, $4, $5, $11, $15, $17, $19, $6, $7, $12, $16, $18, $20, 100-$10, $21/1024/1024, $22/1024/1024) ; }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp

elif [ $ovm_f -eq 1 ]; then
  awk -v size1=${size1t} '{ if ($1 == "==========" || $1 == "*") print $0; \
  else if ($2 == "") (a=1)  ; \
  else if ($2 != "IO") printf("%-*s %4.1f %4.1f %4.1f%6.1f%5.0f%3.0f|%5.1f%5.1f%5.1f%5.0f|%7.1f%7.0f%7.1f%7.0f|%7.1f%7.1f%7.1f%7.1f%8.1f%8.1f\n", \
                       size1, $1, $2,   $3,   $4,  $5,  $6,  $23, $20/10,$21/10,$22/10,$24/1024/1024,$10/1024, $11, $12/1024, $13,  $14,  $15,  $16/1024/1024, $17/1024/1024, $18/1024/1024, $19/1024/1024  ); \
  else printf("%s%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%9.1f\n", \
             $1, $3, $4, $5, $11, $15, $17, $19, $6, $7, $12, $16, $18, $20, 100-$10, $21/1024/1024, $22/1024/1024) ; }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp

elif [ $pmem_f -eq 1 ]; then
  awk -v size1=${size1t} '{ if ($1 == "==========" || $1 == "*") print $0; \
  else if ($2 == "") (a=1)  ; \
  else if ($2 != "IO") printf("%-*s %4.1f %4.1f %4.1f%6.1f%5.0f|%5.1f%5.1f%5.1f|%7.1f%7.0f%7.1f%7.0f|%7.1f%7.1f%7.1f%7.1f%8.1f%8.1f\n", \
                       size1, $1, $2,   $3,   $4,  $5,  $6,  $20/10,$21/10,$22/10,$10, $11, $12, $13,  $14,  $15,  $16/1024/1024, $17/1024/1024, $18/1024/1024, $19/1024/1024  ); \
  else printf("%s%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%9.1f|%9.1f%8.1f%8.1f\n", \
             $1, $3, $4, $5, $11, $15, $17, $19, $6, $7, $12, $16, $18, $20, 100-$10, $21/1024/1024, $22/1024/1024, $26*64/1024/1024, $27*64/1024/1024, $25/1024 ); }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp

elif [ $roce_y -eq 1 ]; then
# ROCE only
awk -v size1=${size1t} -v cc=${CRI_COL} -v wc=${WARN_COL} -v rc=${RESET_COL} -v cpu_c=${CPU_CRI} -v cpu_w=${CPU_WARN} -v io_c=${IO_CRI} -v io_w=${IO_WARN} -v ro_c=${ROCE_CRI} -v ro_w=${ROCE_WARN} -v pm_c=${PMEM_CRI} -v pm_w=${PMEM_WARN} -v mem_c=${MEM_CRI} -v mem_w=${MEM_WARN} \
'{if ($1 == "==========" || $1 == "*") print $0; \
else if ($2 == "") (a=1)  ; \
else if ($2 != "IO") { printf("%-*s ", size1, $1);\
     if ($2>cpu_c) {printf("%s%4.1f%s",cc,$2,rc);} else if ($2>cpu_w) {printf("%s%4.1f%s",wc,$2,rc);} else printf("%4.1f",$2);\
     printf(" %4.1f %4.1f%6.1f%5.0f|", $3, $4, $5, $6);
     if ($20>mem_c*10) {printf("%s%5.1f%s",cc,$20/10,rc);} else if ($20>mem_w*10) { printf("%s%5.1f%s",wc,$20/10,rc);} else printf("%5.1f",$20/10);\
     if ($21>mem_c*10) {printf("%s%5.1f%s",cc,$21/10,rc);} else if ($21>mem_w*10) { printf("%s%5.1f%s",wc,$21/10,rc);} else printf("%5.1f",$21/10);\
     printf("%5.1f|%7.1f%7.0f%7.1f%7.0f|%7.1f%7.1f%7.1f%7.1f", $22/10,$10, $11, $12, $13,  $14,  $15,  $16/1024/1024, $17/1024/1024 );\
     if ($18/1024/1024>ro_c) {printf("%s%8.1f%s",cc,$18/1024/1024,rc);} else if ($18/1024/1024>ro_w) { printf("%s%8.1f%s",wc,$18/1024/1024,rc);} else printf("%8.1f",$18/1024/1024);\
     if ($19/1024/1024>ro_c) {printf("%s%8.1f%s",cc,$19/1024/1024,rc);} else if ($19/1024/1024>ro_w) { printf("%s%8.1f%s",wc,$19/1024/1024,rc);} else printf("%8.1f",$19/1024/1024);\
     printf("\n"); }\
else { printf("%s%7.1f|%7.1f%7.1f", $1, $3, $4, $5);\
     if ($11>io_c) {printf("%s%6.1f%s",cc,$11,rc);} else if ($11>io_w) { printf("%s%6.1f%s",wc,$11,rc);} else printf("%6.1f",$11);\
     if ($15>io_c) {printf("%s%6.1f%s",cc,$15,rc);} else if ($15>io_w) { printf("%s%6.1f%s",wc,$15,rc);} else printf("%6.1f",$15);\
     printf("%8.0f%6.2f|%7.1f%7.1f", $17, $19, $6, $7);\
     if ($12>io_c) {printf("%s%6.1f%s",cc,$12,rc);} else if ($12>io_w) { printf("%s%6.1f%s",wc,$12,rc);} else printf("%6.1f",$12);\
     if ($16>io_c) {printf("%s%6.1f%s",cc,$16,rc);} else if ($16>io_w) { printf("%s%6.1f%s",wc,$16,rc);} else printf("%6.1f",$16);\
     printf("%8.0f%6.2f|", $18, $20);\
     if ($10<100-cpu_c) {printf("%s%5.1f%s",cc,100-$10,rc);} else if ($10<100-cpu_w) { printf("%s%5.1f%s",wc,100-$10,rc);} else printf("%5.1f",100-$10);\
     if ($21/1024/1024>ro_c) {printf("|%s%8.1f%s",cc,$21/1024/1024,rc);} else if ($21/1024/1024>ro_w) { printf("|%s%8.1f%s",wc,$21/1024/1024,rc);} else printf("|%8.1f",$21/1024/1024);\
     if ($22/1024/1024>ro_c) {printf("%s%9.1f%s",cc,$22/1024/1024,rc);} else if ($22/1024/1024>ro_w) { printf("%s%9.1f%s",wc,$22/1024/1024,rc);} else printf("%9.1f",$22/1024/1024);\
     if ($23/1024>pm_c) {printf("|%s%9.1f%s",cc,$23/1024,rc);} else if ($23/1024>pm_w) { printf("|%s%9.1f%s",wc,$23/1024,rc);} else printf("|%9.1f",$23/1024);\
     printf("%8.1f%8.1f\n", $24/1024, $25/1024); } }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp
#
elif [ $ext_f -eq 0 ]; then
awk -v size1=${size1t} -v cc=${CRI_COL} -v wc=${WARN_COL} -v rc=${RESET_COL} -v cpu_c=${CPU_CRI} -v cpu_w=${CPU_WARN} -v io_c=${IO_CRI} -v io_w=${IO_WARN} -v ro_c=${ROCE_CRI} -v ro_w=${ROCE_WARN} -v pm_c=${PMEM_CRI} -v pm_w=${PMEM_WARN} -v mem_c=${MEM_CRI} -v mem_w=${MEM_WARN} \
'{if ($1 == "==========" || $1 == "*") print $0; \
else if ($2 == "") (a=1)  ; \
else if ($2 != "IO") { printf("%-*s ", size1, $1);\
     if ($2>cpu_c) {printf("%s%4.1f%s",cc,$2,rc);} else if ($2>cpu_w) {printf("%s%4.1f%s",wc,$2,rc);} else printf("%4.1f",$2);\
     printf(" %4.1f %4.1f%6.1f%5.0f|", $3, $4, $5, $6);
     if ($20>mem_c*10) {printf("%s%5.1f%s",cc,$20/10,rc);} else if ($20>mem_w*10) { printf("%s%5.1f%s",wc,$20/10,rc);} else printf("%5.1f",$20/10);\
     if ($21>mem_c*10) {printf("%s%5.1f%s",cc,$21/10,rc);} else if ($21>mem_w*10) { printf("%s%5.1f%s",wc,$21/10,rc);} else printf("%5.1f",$21/10);\
     printf("%5.1f|%7.1f%7.0f%7.1f%7.0f|%7.1f%7.1f%7.1f%7.1f", $22/10,$10, $11, $12, $13,  $14,  $15,  $16/1024/1024, $17/1024/1024 );\
     if ($18/1024/1024>ro_c) {printf("%s%8.1f%s",cc,$18/1024/1024,rc);} else if ($18/1024/1024>ro_w) { printf("%s%8.1f%s",wc,$18/1024/1024,rc);} else printf("%8.1f",$18/1024/1024);\
     if ($19/1024/1024>ro_c) {printf("%s%8.1f%s",cc,$19/1024/1024,rc);} else if ($19/1024/1024>ro_w) { printf("%s%8.1f%s",wc,$19/1024/1024,rc);} else printf("%8.1f",$19/1024/1024);\
     printf("\n"); }\
else { printf("%s%7.1f|%7.1f%7.1f", $1, $3, $4, $5);\
     if ($11>io_c) {printf("%s%6.1f%s",cc,$11,rc);} else if ($11>io_w) { printf("%s%6.1f%s",wc,$11,rc);} else printf("%6.1f",$11);\
     if ($15>io_c) {printf("%s%6.1f%s",cc,$15,rc);} else if ($15>io_w) { printf("%s%6.1f%s",wc,$15,rc);} else printf("%6.1f",$15);\
     printf("%8.0f%6.2f|%7.1f%7.1f", $17, $19, $6, $7);\
     if ($12>io_c) {printf("%s%6.1f%s",cc,$12,rc);} else if ($12>io_w) { printf("%s%6.1f%s",wc,$12,rc);} else printf("%6.1f",$12);\
     if ($16>io_c) {printf("%s%6.1f%s",cc,$16,rc);} else if ($16>io_w) { printf("%s%6.1f%s",wc,$16,rc);} else printf("%6.1f",$16);\
     printf("%8.0f%6.2f|", $18, $20);\
     if ($10<100-cpu_c) {printf("%s%5.1f%s",cc,100-$10,rc);} else if ($10<100-cpu_w) { printf("%s%5.1f%s",wc,100-$10,rc);} else printf("%5.1f",100-$10);\
     if ($21/1024/1024>ro_c) {printf("|%s%8.1f%s",cc,$21/1024/1024,rc);} else if ($21/1024/1024>ro_w) { printf("|%s%8.1f%s",wc,$21/1024/1024,rc);} else printf("|%8.1f",$21/1024/1024);\
     if ($22/1024/1024>ro_c) {printf("%s%9.1f%s\n",cc,$22/1024/1024,rc);} else if ($22/1024/1024>ro_w) { printf("%s%9.1f%s\n",wc,$22/1024/1024,rc);} else printf("%9.1f\n",$22/1024/1024);\
     } }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp
#awk -v size1=${size1t} '{ if ($1 == "==========" || $1 == "*") print $0; \
#else if ($2 == "") (a=1)  ; \
#else if ($2 != "IO") printf("%-*s %4.1f %4.1f %4.1f%6.1f%5.0f|%5.1f%5.1f%5.1f|%7.1f%7.0f%7.1f%7.0f|%7.1f%7.1f%7.1f%7.1f%8.1f%8.1f\n", \
#                       size1, $1, $2,   $3,   $4,  $5,  $6,  $20/10,$21/10,$22/10,$10, $11, $12, $13,  $14,  $15,  $16/1024/1024, $17/1024/1024, $18/1024/1024, $19/1024/1024  ); \
#else printf("%s%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%9.1f\n", \
#             $1, $3, $4, $5, $11, $15, $17, $19, $6, $7, $12, $16, $18, $20, 100-$10, $21/1024/1024, $22/1024/1024); }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp

else
echo size real ${size1t}
awk -v size1=${size1t} '{ if ($1 == "==========" || $1 == "*") print $0; \
else if ($2 == "") (a=1)  ; \
else if ($2 != "IO") printf("%-*s %4.1f %4.1f %4.1f %4.1f%6.1f%5.0f|%5.1f%5.1f%5.1f|%7.1f%7.0f%7.1f%7.0f|%7.1f%7.1f%7.1f%7.1f%8.1f%8.1f\n", \
                       size1, $1, $2,  $7,   $3,   $4,  $5,  $6,   $20/10,$21/10,$22/10,$10, $11, $12, $13,  $14,  $15,  $16/1024/1024, $17/1024/1024, $18/1024/1024, $19/1024/1024  ); \
else printf("%s%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%9.1f\n", \
             $1, $3, $4, $5, $11, $15, $17, $19, $6, $7, $12, $16, $18, $20, 100-$10, $21/1024, $22/1024) ; }' /tmp/sa1_$t.tmp > /tmp/saf_$t.tmp
 cat /tmp/saf_$t.tmp
fi

if [ "$prod" == "xl" ]; then
 cat /tmp/saz_$t.tmp >> /tmp/saf_$t.tmp
else
 if [ $roce_y -eq 1 ]; then
   echo "---------- I/O Disk Total --------------------------------------------------------------------------------------------------------------------------------" >> /tmp/saf_$t.tmp
   echo $spa2 | sed s/Z/" "/g | awk '{ printf("* TOT %s:", $0)}' >> /tmp/saf_$t.tmp
   awk 'BEGIN {t1=0;t2=0;t3=0;t4=0;t5=0} {if ($2 == "IO") (t1 +=$3) (t2 +=$4)(t3 +=$5)(t4 +=$11)(t5 +=$15)(t6 +=$17)(t7 +=$19)(t8 +=$6)(t9 +=$7)(t10 +=$12)(t11 +=$16)(t12 +=$18)(t13 +=$20)(t14 +=$10)(t15 +=$21)(t16 +=$22)(t17 +=$23)(t18 +=$24)(t19 +=$25)(cnt +=1);} END {if (cnt == 0) (cnt=1); printf("%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%9.1f|%9.1f%8.1f%8.1f\n", t1, t2, t3, t4/cnt, t5/cnt, t6, t7/cnt, t8, t9, t10/cnt, t11/cnt, t12, t13/cnt, 100-t14/cnt, t15/1024/1024, t16/1024/1024, t17/1024, t18/1024, t19/1024) ; }' /tmp/sa1_$t.tmp >> /tmp/saf_$t.tmp
 else
   echo "---------- I/O Disk Total --------------------------------------------------------------------------------------------------" >> /tmp/saf_$t.tmp
   echo $spa2 | sed s/Z/" "/g | awk '{ printf("* TOT %s:", $0)}' >> /tmp/saf_$t.tmp
   awk 'BEGIN {t1=0;t2=0;t3=0;t4=0;t5=0} {if ($2 == "IO") (t1 +=$3) (t2 +=$4)(t3 +=$5)(t4 +=$11)(t5 +=$15)(t6 +=$17)(t7 +=$19)(t8 +=$6)(t9 +=$7)(t10 +=$12)(t11 +=$16)(t12 +=$18)(t13 +=$20)(t14 +=$10)(t15 +=$21)(t16 +=$22)(t17 +=$23)(t18 +=$24)(t19 +=$25)(cnt +=1);} END {if (cnt == 0) (cnt=1); printf("%7.1f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%7.1f%7.1f%6.1f%6.1f%8.0f%6.2f|%5.1f|%8.1f%9.1f\n", t1, t2, t3, t4/cnt, t5/cnt, t6, t7/cnt, t8, t9, t10/cnt, t11/cnt, t12, t13/cnt, 100-t14/cnt, t15/1024/1024, t16/1024/1024) ; }' /tmp/sa1_$t.tmp >> /tmp/saf_$t.tmp
 fi
fi

 if [ $dsk_f -ne "0" ]; then
  echo "==  Disk IO ====== IOPS (1 min more delay) ======= ========= Mbytes/Sec ========= =========== usec/request ========= " >> /tmp/saf_$t.tmp
  echo $spa2 | sed s/Z/" "/g | awk '{ printf("= Cellcli %s SM_R    SM_W    LG_R    LG_W   TOTAL|  SM_R   SM_W   LG_R   LG_W  TOTAL|   SM_R    SM_W    LG_R    LG_W\n", $0)}' >> /tmp/saf_$t.tmp
  sort /tmp/cel2_$t.tmp | awk '{ printf("%s %7.0f %7.0f %7.0f %7.0f %7.0f|%6.1f %6.1f %6.1f %6.1f %6.1f|%7.1f %7.1f %7.1f %7.1f\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15) }' >> /tmp/saf_$t.tmp
  echo "= From Flash  SM_R    SM_W    LG_R    LG_W   TOTAL|  SM_R   SM_W   LG_R   LG_W  TOTAL|   SM_R    SM_W    LG_R    LG_W" >> /tmp/saf_$t.tmp
  sort /tmp/cel3_$t.tmp | awk '{ printf("%s %7.0f %7.0f %7.0f %7.0f %7.0f|%6.1f %6.1f %6.1f %6.1f %6.1f|%7.1f %7.1f %7.1f %7.1f\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15) }' >> /tmp/saf_$t.tmp
 fi

if [ $top_f -eq 1 ]; then
  echo "=== Top Process =======" >> /tmp/saf_$t.tmp
  echo $spa1 | sed s/Z/" "/g | awk '{ printf("* Node%s:", $0)}' >> /tmp/saf_$t.tmp
  echo " `top -b | head -7 | tail -1 | cut -b1-70`" >> /tmp/saf_$t.tmp

  head_cnt=`expr $top_cnt + 7`
  while read line
  do
    echo "`ssh ${line} ${SSH_DB_OPTION} \"top -b | head -${head_cnt} | tail -${top_cnt} | cut -b1-70\"`" >> /tmp/sat_${line}_$t.tmp &
  done < $v_dbs_group_file
  wait

  while read line
  do
    echo "-------------------------------------------------------------------------------" >> /tmp/saf_$t.tmp
    sed -e 's/^/: /' /tmp/sat_${line}_$t.tmp > /tmp/sat2_${line}_$t.tmp
    while read line2
    do
      echo "${line}${line2}" >> /tmp/saf_$t.tmp
    done < /tmp/sat2_${line}_$t.tmp
    rm /tmp/sat2_${line}_$t.tmp
    rm /tmp/sat_${line}_$t.tmp
  done < $v_dbs_group_file
fi

if [ $mon_f -eq 1 ]; then
  echo DB Event Monitoring.... >> /tmp/saf_$t.tmp
  sh dbmon.sh | head -20 >> /tmp/saf_$t.tmp
fi

if [ $log_f -eq 1 ]; then
  #echo Current Logging....
  file_name=sar_`date +%Y%m%d`.log
  #if [ -f $log_dir/$file_name ] ;  then
    cat /tmp/saf_$t.tmp >> $log_dir/$file_name
  #else
    #find $log_dir/sar_*.log  -mtime +60 > /tmp/dfile.tmp
    #while read dline
    #do
    #  rm -f $dline 
    #  echo file $dline deleted
    #done < /tmp/dfile.tmp
    #cat /tmp/saf_$t.tmp > $log_dir/$file_name
  #fi
else
  if [ $debug_f -eq 0 ] ; then
    clear
  fi
  cat /tmp/saf_$t.tmp
  #cat /tmp/saf_$t.tmp|echo
fi

if [ $2 -gt 0 ] ; then
  i=`expr $i + 1`
fi

done
