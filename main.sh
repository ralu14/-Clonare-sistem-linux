#!/bin/bash
if [[ $# -eq 0 ]]
then
    echo "Ati uitat sa specificati si calea catre locul unde este salvat directorul de clonare/recreare"
    exit 0
else
    cd "$1"
fi
PS3="Alege o optiune din meniu " 
select ITEM in "Clonare sistem linux" "Recreare sistem linux" "Exit" 
do 
    case $REPLY in 
        1) 
        sudo chmod u+x clonare.sh
        user=`whoami`
            sudo ./clonare.sh $user 
            exit 0 ;; 
        2) read -p "Intoduceti locatia unde se afla directorul care contine backup-ul sistemului linux" location
        sudo chmod u+x recreare.sh
            sudo ./recreare.sh $location
            exit 0 ;; 
        3) exit 0 ;;   
        *) echo "Optiune incorecta" 
    esac
done 