#!/bin/bash
backup_dir="/backup"
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

###########################ATENTIE , TOT CE SE CREEAZA SE SALVEAZA IN NOUL DIRECTOR CREAT backup_dir ##################################

#copiere utilizatori cu home_dir lor

user_file="user_details.txt"
shadow_file="shadow_details.txt"
group_file="group_details.txt"


while read line
do
	user=`cut -f1 -d: <<<$line`
	if [[ $user != "root" ]]
	then
		shell=`cut -f7 -d: <<<$line`
		if [[ $shell == "/bin/bash" || $shell == "/bin/sh" ]]
		then
			 echo "$line" >> $user_file
       			pass_user=`sudo egrep "^$user:" /etc/shadow` 
       			echo "$pass_user" >> $shadow_file
       			id_gr_principal=`cut -f4 -d: <<<$line`
       			grup_principal=`sudo egrep "$id_gr_principal" /etc/group`
       			if [[ -n $grup_principal ]]
       			then
       				echo "$grup_principal" >>$group_file
       			fi	
       		
       			while read linie
       			do
       				verf=`sudo cut -f4 -d: <<<$linie | egrep "$user"`
       				if [[ -n $verf ]]
       				then
       					echo "$linie" >>$group_file
       				fi
       			done < /etc/group
		fi
	fi
done < /etc/passwd

old_ifs=$IFS
IFS=:

while read -r user pass uid gid gecos home shell
do
    if [[ -d $home ]]
    then
        echo "Copierea directorului home pentru $user..."
        sudo rsync -a "$home" "$backup_dir"
    fi
done < user_details.txt

IFS=$old_ifs

#copiere pachete instalate pe sistem 

dpkg-query -W -f='${binary:Package}\t${Version}\n' > installed_packages.txt


# copiere fisiere de configurare de retea

network_config_archive="$backup_dir/network_config.tar.gz"
sudo tar czf "$network_config_archive" /etc/network /etc/netplan /etc/resolv.conf /etc/hosts /etc/nsswitch.conf /etc/hostname /etc/NetworkManager/system-connections

network_packages=("net-tools" "iproute2" "network-manager" "dhclient" "wpa_supplicant" "iptables")
for package in "${network_packages[@]}"
do
    if dpkg -s $package &> /dev/null
    then
        dpkg-query -W -f='${binary:Package}\t${Version}\n' $package >> network_packages.txt
    fi
done

# copiere versiune kernel
uname -r > kernel_version.txt


#copiere fisiere de configurare

sudo tar czf "$backup_dir/system_backup.tar.gz" --exclude="$backup_dir" --exclude="/dev" --exclude="/etc" --exclude="/proc" --exclude="/sys" --exclude="/tmp" --exclude="/run" --exclude="/mnt" --exclude="/media" --exclude="/lost+found" /
