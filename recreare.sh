#!/bin/bash

user_file="user_details.txt"
shadow_file="shadow_details.txt"
group_file="group_details.txt"

# Verificăm dacă fișierele de intrare există

if [[ ! -f $user_file || ! -f $shadow_file || ! -f $group_file ]]
then
    echo "Fișierele necesare trebuie să existe în directorul curent."
    exit 1
fi

# Cream utilizatorii,grupurile si  configurăm parolele lor
while read line
do
	grup_list=`cut -f2 -d: <<<$line`
	olf_ifs=$IFS
	IFS=","
	for i in grup_list
	do
		verf_i=`sudo egrep "^$i" /etc/group`
		if [[ -n $verf_i ]]
		then
			echo "exista deja grupul $i"
		else
			sudo groupadd $i
		fi
	done
	IFS="$old_ifs"
	
done < $group_file

while IFS=: read -r user pass uid gid gecos home shell
do
	backup_home="/media/backup_home"

	# Asigură-te că backup_home este montat și disponibil

	old_ifs=$IFS
	IFS=:

	while read -r user pass uid gid gecos home shell
	do
	    if [[ -d $backup_home/$(basename $home) ]]
	    then
		echo "Restaurarea directorului home pentru $user..."
		sudo rsync -a "$backup_home/$(basename $home)/" "$home/"
		sudo chown -R $user:$gid "$home"
	    fi
	done < $user_file

	IFS=$old_ifs
	
	sudo usermod -c "$gecos" -d $home -m -g "ceva" -a -G "altceva" -s $shell $user
	sudo usermod -p $(egrep "^$user:" $shadow_file | cut -d: -f2) $user
done < $user_file

echo "Utilizatorii au fost creați cu succes pe noul sistem."

echo "Restaurarea directoarelor home a fost completă."
