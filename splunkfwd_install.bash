#! /bin/bash -x
# Script to install splunk on open systems servers -- run this with sudo
# By Chidi Ezuma-Ngwu
# Date: 08/08/2016
# Revision: 0.1
# 
# Global Settings
#
########Change Block###########
#SPLUNKUSER=splunk
#SPLUNKGRP=splunkgrp
SPLUNKUSER=ce898
SPLUNKGRP=unixadm
INSTALLBINARY=/PHShome/$SPLUNKUSER
SPLUNKDIR=/opt/splunkforwarder
########End of Change Block####

FILESOURCE=nfs	# The location of the file can be local or nfs
# SPLUNKAPP=$INSTALLBINARY/<ostype>/phs_all_deploymentclient.tar # set in code
SPLUNKRPM=splunkforwarder-6.3.3-f44afce176d0.x86_64
SPLUNKAPPHOME=$SPLUNKDIR/etc/apps
SPLUNKBINHOME=$SPLUNKDIR/bin
RPM=/bin/rpm
TAR=/bin/tar
TMPDIR=/tmp
INSTALLTYPE=


# function check_rootacct {
# # Validate that the root user is running this.
	# if [[ $EUID -ne 0 ]]; then
		# echo "The Splunk installer script must be run as root" 
		# exit 1
	# else
		# echo "Running as root -- as expected"
	# fi
# }

# function check_splunkfwdacct {
# # Validate the existence of the splunk account
	# /bin/id $USERID || echo "Splunk user account required to continue ..."; exit 1
# }

function platform {
	#FIRSTSTARTCMD="$SPLUNKBINHOME/splunk start -user $SPLUNKUSER" #The -user entry is not supported at first start
	FIRSTSTARTCMD="su $SPLUNKUSER -c $SPLUNKBINHOME/splunk start" #using su - c instead
	case "$OSTYPE" in
		solaris*) 	
			echo "SOLARIS not supported yet"; exit 1 ;;
		darwin*)  	
			echo "OSX not supported"; exit 1 ;; 
		linux*)  	
			echo "Found linux in platform routine"
			if [[ $(uname -m) = "x86_64" ]]; then
				echo "Found 64 bit Linux"
				FILENAME="splunkforwarder-6.3.3-f44afce176d0-linux-2.6-x86_64.rpm"
				INSTALLTYPE=RPM
				SERVERTYPE=LINUX
				RPM=/bin/rpm
				INSTALLBINARY=$INSTALLBINARY/linux
				SPLUNKAPP=$INSTALLBINARY/phs_all_deploymentclient.tar
				STOPCMD="$SPLUNKBINHOME/splunk stop -user $SPLUNKUSER"
				STARTCMD="$SPLUNKBINHOME/splunk start -user $SPLUNKUSER"
			else
				echo "This package is only for use on 64 bit Linux"
				exit 1
			fi
			;;
		aix*)	
			echo "Found AIX server in checkplatform routine"	
			FILENAME="splunkforwarder-6.4.2-00f5bb3fa822-AIX-powerpc.tar"
			INSTALLTYPE=TGZ
			SERVERTYPE=AIX
			INSTALLBINARY=$INSTALLBINARY/aix
			SPLUNKAPP=$INSTALLBINARY/phs_all_deploymentclient.tar
			[[ -f /opt/freeware/bin/tar ]] && TAR=/opt/freeware/bin/tar || TAR=/usr/bin/tar
			STOPCMD="/usr/bin/stopsrc -s splunkd"
			STARTCMD="/usr/bin/startsrc -s splunkd"
			;;
		bsd*)   echo "BSD not supported"; exit 1 ;;
		*)      echo "unknown: $OSTYPE ... exiting"; exit 1;;
	esac
}

# function createtmpdir {
# #Create temporary directory first
	# [[ ! -d $TMPDIR ]] && mkdir $TMPDIR
# }

# function setupfilesource {
# # #Mount or set local directory
	# case "$FILESOURCE" in
		# nfs) 	#Mount nfs filesystem
			# #mount .... 
			# #EXECFILE=
		# ;;
		# local)	#Copy from local directory
			# EXECFILE="$TMPDIR"/"$FILENAME"
		# ;;
	# *) echo "File location error"
	# esac
# }

function installsplunkfwd {
# Install Splunk based on RPM or Compressed tar bundle
	echo "Starting installation routine ..."
	case "$INSTALLTYPE" in
		RPM)  	
			if [[ $SERVERTYPE = "LINUX" && -f $INSTALLBINARY/$FILENAME ]]; then
				echo "Installing RPM on Linux"
				$RPM -i $INSTALLBINARY/$FILENAME
			else
				echo "Install binary: $INSTALLBINARY/$FILENAME is missing ... exiting"
				exit 1
			fi
		;;
		TGZ)  
			if [[ $SERVERTYPE = "AIX" && -f $INSTALLBINARY/$FILENAME ]]; then	
				echo "Assuming AIX tar installation"
				cd /opt
				$TAR xvf $INSTALLBINARY/$FILENAME
				chown -Rh $SPLUNKUSER:$SPLUNKGRP $SPLUNKDIR
			else
				echo "Install binary: $INSTALLBINARY/$FILENAME is missing ... exiting"
				exit 1
			fi
		;;
		*) echo "Did not find appropriate file type" ;;
	esac
}

function setupapp {
	echo "Extracting deployment app binary"
	if [[ -d $SPLUNKAPPHOME && -f $SPLUNKAPP ]]; then
		cd $SPLUNKAPPHOME
		tar xvf $SPLUNKAPP
		resetfiles #reapply ownership to files
	else
		echo "Missing Splunk deployment application files ... exiting"
		exit 1
	fi
}

function bootstart {
	echo "Running boot start to set boot time initiation of splunk forwarder"
	#Run this a root to make sure privileged files are set correctly
	$SPLUNKBINHOME/splunk enable boot-start -user $SPLUNKUSER
	# [[ $SERVERTYPE = "AIX" ]] && rmitab splunk   # Remove AIX startsrc issue for splunk user
}

function setpassword {
	echo "Setting internal splunk account password"
	su $SPLUNKUSER -c "$SPLUNKBINHOME/splunk edit user admin -password splunk4Fun -auth admin:changeme --accept-license"
}

function resetfiles {
	# Make sure files are owned by the user splunk
	echo "Changing file ownership to $SPLUNKUSER"
	chown -Rh $SPLUNKUSER:$SPLUNKGRP $SPLUNKDIR
}

function splunkfirststart {
	setlimits
	echo "Starting splunk first time"
	eval $FIRSTSTARTCMD
}

function splunkstart {
	setlimits
	echo "Starting splunk anytime"
	eval $STARTCMD
}

function splunkstop {
	echo "Stopping splunk process"
	eval $STOPCMD
}

function uninstall {
	echo "Uninstalling splunk process"
	splunkstop #Stop Splunk
	if [[ $SERVERTYPE = "LINUX" && -d $SPLUNKDIR ]]; then
			echo "Removing Splunk RPM: $SPLUNKRPM"
			$RPM -e $SPLUNKRPM && echo "Deleting: $SPLUNKDIR"; rm -rf $SPLUNKDIR
	elif [[ $SERVERTYPE = "AIX" && -d $SPLUNKDIR ]]; then
		echo "Deleting: $SPLUNKDIR"
		rm -rf $SPLUNKDIR
	fi
}

function setlimits {
	echo "Setting file limits"
	su $SPLUNKUSER -c "ulimit -d unlimited"
	su $SPLUNKUSER -c "ulimit -m unlimited"
	su $SPLUNKUSER -c "ulimit -f unlimited"
}


function splunk_install {
platform
installsplunkfwd  #extract files as root
resetfiles
setpassword
setupapp   #extract files as root
setlimits
resetfiles
splunkfirststart
bootstart && resetfiles || echo "Boot setting failed"
}

function splunk_uninstall {
splunkstop
uninstall
}

splunk_install