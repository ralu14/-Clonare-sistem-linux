#!/bin/bash

backup_dir="/backup" #asta e numele pentru moment
system_backup_archive="$backup_dir/system_backup.tar.gz"

# Restauram sistemul de fisiere din arhiva

echo "Restaurarea sistemului de fisiere..."
sudo tar xzf "$system_backup_archive" -C /
echo "Restaurarea sistemului de fisiere este completa."


user_file="user_details.txt"
shadow_file="shadow_details.txt"
group_file="group_details.txt"


# Verificam daca fisierele de intrare exista

if [[ ! -f $user_file || ! -f $shadow_file || ! -f $group_file ]]
then
    echo "Fisierele necesare trebuie sa existe in directorul curent."
    exit 1
fi

# Cream utilizatorii,grupurile si  configuram parolele lor
while read line
do
	nume_grup=`sudo cut -f1 -d: <<<$line`
	verf=`sudo egrep "^$nume_grup" /etc/group`
	if [[ -n $verf ]] 
	then
		echo "Exista deja grupul $nume_grup"
	else	
		echo "Se creeaza grupul $nume_grup ..."
		grup_id=`cut -f3 -d: <<<$line`
		sudo groupadd -g "$grup_id" "$nume_grup"
	fi		
	
done < $group_file

while IFS=: read -r user pass uid gid gecos home shell
do
	#aici creez home directory pentru fiecare user
	
	if [[ ! -d "/home/""$home" ]]
	then
		echo "Restaurarea directorului home pentru $user..."
		sudo rsync -a "$backup_dir/$(basename $home)/" "/home/"
		sudo chown -R $user:$gid "$home"
	fi
	
	grupuri_secundare=""
	while read line
	do
		
		#aici setez grupul principal
		
		id_grup=`cut -f3 -d: <<<$line`
		if [[ "$id_grup" = "$gid" ]]
		then
			grup_principal=`cut -f1 -d: <<<$line`
		fi
		
		#aici setez lista cu grupuri secundare ,daca este cazul
		
		if [[ "$grupuri_secundare" != "" ]]
		then
			grupuri_secundare="$grupuri_secundare,"
		fi
		
		verf_grup=`cut -f4 -d: <<<$line| egrep "$user"`
		if [[ -n $verf_grup ]]
		then
			nume_gr_sec=`cut -f1 -d: <<<$line`
			grupuri_secundare="$grupuri_secundare""$nume_gr_sec"
		fi
	done <$group_file
	
	if [[ -n "$grupuri_secundare" ]]
	then
		sudo usermod -c "$gecos" -d $home -m -g "$grup_principal" -a -G "$grupuri_secundare" -s $shell $user
	else
		sudo usermod -c "$gecos" -d $home -m -g "$grup_principal"  -s $shell $user
	fi
	
	sudo usermod -p $(egrep "^$user:" $shadow_file | cut -d: -f2) $user
	
done < $user_file

echo "Utilizatorii au fost creati cu succes pe noul sistem."

echo "Restaurarea directoarelor home a fost completa."

# Instalam pachetele de sistem din installed_packages.txt
installed_packages_file="$backup_dir/installed_packages.txt"

while IFS=$'\t' read -r package version
do
    echo "Instalare $package versiunea $version"
    sudo apt-get install -y "$package=$version"
done < "$installed_packages_file"

echo "Toate pachetele de sistem au fost reinstalate cu versiunile specifice."

# Restauram configurarile de retea
network_config_archive="$backup_dir/network_config.tar.gz"
network_packages_file="$backup_dir/network_packages.txt"

sudo tar xzf "$network_config_archive" -C /

echo "Configurarile de retea au fost restaurate."

# Instalam pachetele de retea specifice din network_packages.txt
while IFS=$'\t' read -r package version
do
    echo "Instalare pachet de retea $package versiunea $version"
    sudo apt-get install -y "$package=$version"
done < "$network_packages_file"

echo "Pachetele de retea au fost instalate."


##restaurare versiune de *kernel* 

# Comparam versiunea de kernel si facem upgrade daca este necesar

echo "Compararea versiunii de kernel..."
current_kernel_version=`uname -r`
backup_kernel_version=`cat "$kernel_version_file"`

if [ "$current_kernel_version" != "$backup_kernel_version" ]
then
    echo "Versiunea de kernel difera. Se va face upgrade de la $current_kernel_version la $backup_kernel_version."
    sudo apt-get update
    sudo apt-get install -y linux-image-$backup_kernel_version linux-headers-$backup_kernel_version
    sudo update-grub
    echo "Kernel-ul a fost actualizat. Sistemul va fi restartat pentru a încarca noul kernel."
    sudo reboot
else
    echo "Kernel-ul este deja la versiunea specificata: $current_kernel_version."
fi
