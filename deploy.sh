#!/bin/bash

sed -E 's/[^0-9°′″]/ /g; s/°|′|″/ /g' lat.txt > fix-lat.txt

awk '{
    degrees=$1;
    minutes=$2;
    seconds=$3;
    dec_deg = degrees + (minutes / 60) + (seconds / 3600);
    printf("%.6f\n", dec_deg);
}' fix-lat.txt > decimal-lat.txt
