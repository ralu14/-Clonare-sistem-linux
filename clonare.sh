#!/bin/bash
backup_dir='/backup'
if [[ -d $backup_dir ]]
then
	echo -e "Atentie,exista deja directorul /backup \n"
	PS3="Alege o optiune din meniu " 
	select ITEM in "Creaza alt director de backup" "Renunta la operatiunea de clonare" 
	do 
	    case $REPLY in 
		1)read -p "Introduceti toata calea catre noul director de backup " backup_dir
		if [[ -d $backup_dir ]]
		then
			echo "Exista $backup_dir deja. Reia procesul!"
			exit 0
		else
			sudo mkdir -p $backup_dir
			break
		fi ;;	
		2) exit 0 ;;   
		*) echo "Optiune incorecta" 
	    esac
	done 
else	
	sudo mkdir -p $backup_dir
fi

cd "$backup_dir"

#copiere toate fisiere din sistem 

lista_directoare=`ls /`
echo $lista_directoare

for i in $lista_directoare
do
	if [[ "/""$i" != $backup_dir ]]
	then
		sudo tar czvf "arhiva_""$i"".tar" "/""$i"
	fi
done

#copiere pachete instalate pe sistem 

dpkg --get-selections | cut -f1 > installed_packeges.txt


