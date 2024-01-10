#!/opt/homebrew/bin/gnuplot --persist

# set term qt font "Helvetica,10" size 500,200

set terminal png font "Helvetica,9" size 500,200
set output "VF_LON.png"

set xdata time
set xtics format "%H%M"
set timefmt "%Y-%m-%dT%H:%M:%SZ"
set datafile separator comma
set yrange [0:]
set ylabel "Round-trip latency over TCP (ms)"

set style fill transparent solid 0.3 noborder

#set linetype 1 linecolor rgb "#343049"
#set linetype 2 linecolor rgb "#493A34"
#set linetype 3 linecolor rgb "#BA8E69"

set title "Vodafone - London WLZ versus Region on 4G\nUE near Cambridge"

az="< fgrep -- '-az' vf_lon.csv"
wlz="< fgrep -- '-wlz' vf_lon.csv"

plot az using 7:3 with lines lt 1 title "Region", wlz using 7:3 with lines lt 2 title "WLZ"