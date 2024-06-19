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

echo "Backup pentru utilizatori ..."
sudo cp /etc/passwd $backup_dir/passwd.bak
sudo cp /etc/group $backup_dir/group.bak
sudo cp /etc/shadow $backup_dir/shadow.bak
sudo cp /etc/gshadow $backup_dir/gshadow.bak

old_ifs=$IFS
IFS=$'\n'
set -x
for line in $( cat /etc/passwd ) 
do
	username=$(cut -f1 -d: <<<$line)
	echo "$username"
	home_dir=$(cut -f6 -d: <<<$line)
	echo "$home_dir"
	if [[ -d $home_dir ]]
	then
		sudo tar czf "$backup_dir""/""$username_home_dir_backup.tar.gz" "$home_dir" 2>/dev/null
		echo "sunt aici"
	fi
done

IFS=$old_ifs


