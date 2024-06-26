#!/bin/bash

PS3="Alege o optiune din meniu" 
select ITEM in "Clonare sistem linux" "Recreare sistem linux" "Exit" 
do 
    case $REPLY in 
        1) sudo chmod +x clonare.sh
            sudo ./clonare.sh ;; 
        2) sudo chmod +x recreare.sh
            sudo ./recreare.sh ;; 
        3) exit 0 ;;   
        *) echo "Optiune incorecta" 
    esac
done 