set bmargin 4
set key spacing 1.0
set key top left
set xlabel "Esclavos" font "helvetica,24"
set ylabel "Aceleracion" font "helvetica,24
set title "Aceleracion - Matrices 2000x2000"
set term postscript eps "helvetica,24"
set xtics font "helvetica,18"
set ytics font "helvetica,18"
set output "speedup_2000.eps"
plot "speedup_2000_open" title "GRID::Machine (open)" with linespoints, "speedup_2000_open2" title "GRID::Machine (open2)" with linespoints, "speedup_2000_globus" title "Globus" with linespoints
