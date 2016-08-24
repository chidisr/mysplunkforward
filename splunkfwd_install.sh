#! /bin/bash
# Script to install splunk on open systems servers
# By Chidi Ezuma-Ngwu
# Date: 08/08/2016
# Revision: 0.1
# 
# Global Settings
#
USERID="splunk"
FILESOURCE=nfs	# The location of the file can be local or nfs
TMPDIR=/tmp/splunk
INSTALLTYPE=

function check_rootacct {
# Validate that the root user is running this.
	if [[ $EUID -ne 0 ]]; then
		echo "The Splunk installer script must be run as root" 
		exit 1
	else
		echo "Running as root -- as expected"
	fi
}

function check_splunkfwdacct {
# Validate the existence of the splunk account
	/bin/id $USERID || echo "Splunk user account required to continue ..."; exit 1
}

function check_platform {
	case "$OSTYPE" in
		solaris*) echo "SOLARIS not supported yet"; exit 1 ;;
		darwin*)  echo "OSX not supported"; exit 1 ;; 
		linux*)   
			if [[ $(uname -m) = "x86_64" ]]; then
				echo "Found 64 bit Linux"
				FILENAME="splunkforwarder-6.3.3-f44afce176d0-linux-2.6-x86_64.rpm"
				INSTALLTYPE=RPM
				SERVERTYPE=LINUX
				RPM=/bin/rpm
			else
				echo "This package is only for use on 64 bit Linux"
				exit 1
			fi
			;;
		aix*)	echo "Found AIX server"	
				FILENAME="splunkforwarder-6.4.2-00f5bb3fa822-AIX-powerpc.tgz"
				INSTALLTYPE=TGZ
				SERVERTYPE=AIX
				;;
		bsd*)   echo "BSD not supported"; exit 1 ;;
		*)      echo "unknown: $OSTYPE ... exiting"; exit 1;;
	esac
}

function createtmpdir {
#Create temporary directory first
	[[ ! -d $TMPDIR ]] && mkdir $TMPDIR
}

function setupfilesource {
#Mount or set local directory
	case "$FILESOURCE" in
		nfs) 	#Mount nfs filesystem
			#mount .... 
			#EXECFILE=
		;;
		local)	#Copy from local directory
			EXECFILE="$TMPDIR"/"$FILENAME"
		;;
	*) echo "File location error"
	esac
}

function installsplunkfwd {
# Install Splunk based on RPM or Compressed tar bundle
	case "$INSTALLTYPE" in
		RPM)  	if [[ $SERVERTYPE = "LINUX" ]]; then
					$RPM -i $FILENAME
				fi
		;;
		TGZ)   ;;
		*) echo "Install type should be compressed Tar or RPM"
	esac
}

function setup_splunkapp {
#Remove the inittab entry for AIX servers ....
}

function cleanup {

}

#Install sequence
check_rootacct
check_splunkfwdacct
check_platform
createtmpdir
setupfilesource
installsplunkfwd
setup_splunkapp
cleanup
