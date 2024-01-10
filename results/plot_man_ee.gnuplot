#!/opt/homebrew/bin/gnuplot --persist

# set term qt font "Helvetica,10" size 500,200

set terminal pngcairo font "Ember,12" size 600,300 truecolor enhanced
set output "bt-man.png"

set xdata time
set xtics format "%H%M"
set timefmt "%Y-%m-%dT%H:%M:%SZ"
set datafile separator comma
set yrange [0:]
set ylabel "Round-trip latency over TCP (ms)" font ",10"

set style fill transparent solid 0.3 noborder

#set linetype 1 linecolor rgb "#343049"
#set linetype 2 linecolor rgb "#493A34"
#set linetype 3 linecolor rgb "#BA8E69"

set title "BT - Manchester WLZ versus Region on 5G\nUE near Cambridge"

#az="< fgrep -- '-az' ee_man.csv"
#wlz="< fgrep -- '-wlz' ee_man.csv"

az = "ee_man_az.csv"
wlz= "ee_man_wlz.csv"

plot az using 7:3 with lines lt 1 title "Region", wlz using 7:3 with lines lt 2 title "WLZ"