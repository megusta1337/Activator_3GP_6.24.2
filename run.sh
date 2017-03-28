#!/bin/ksh
#
# Keldo's activator script modified by DarkDll
#
# Created for the people of Cartechnology Forum
# http://cartechnology.co.uk/
#

# Find the SD Card
sdcard=`ls /mnt|grep sdcard.*t`

# Define destination path
dstPath=/mnt/$sdcard

# Log file
logfile="$dstPath/install.log"

# Mount the SD card for read/write
mount -uw $dstPath

# Change dir to destination path
cd $dstPath

# Show image and wait to key press
show_screen(){
    $dstPath/utils/showScreen "$dstPath/screens/$1"
}

# Save message log to file
flog(){
    # Timestamp
    local tstamp=`date +"%m/%d/%Y ""%T"`
    echo -ne "$tstamp - $1\r\n" >> $logfile
}

# Remove script temporal files
remove_script(){
    /bin/rm -f /tmp/copie_scr.sh
    echo > /tmp/copie_scr.sh
    /bin/rm -f /tmp/run.sh
    echo > /tmp/run.sh
}

# MME Becker Script Creator
create_mme_becker(){

    # Echo script to file
    cat << 'EOF' > $1
#!/bin/ksh
if test -a /HBpersistence/DLinkReplacesPPP ; then
  (while true
   do
     XX=`ifconfig uap0 2>/dev/null`
     if [ ! -z "$XX" ]
     then
       while true
       do
         XX=`ifconfig uap0 | grep "alias"`
         if [ ! "$XX" == "" ]
         then
           exit 0
         fi
         /usr/sbin/dhcp.client -a -i uap0 -m -u
         sleep 1
       done
     fi
     sleep 1
   done) &
fi

(waitfor /mnt/lvm/acios_db.ini 180 && sleep 10 && slay vdev-logvolmgr) &

/sbin/mme-becker $@
EOF

    # check if script was created
    if test -a $1 ; then
        flog "The $1 script was successfully created"

        # Make script executable
        chmod 777 $1
    else
        flog "Error, the $1 script could not be created"
    fi
}

# Show welcome screen
show_screen "process_start.png"

# Write to log
flog "Map activation started."

# Find the fsc file
FSC=`ls *.fsc | sed -n 1p`

# Test if fsc file was found
if [ "$FSC" == "" ]; then
    # Write to log
    flog "Error, The FSC file was not found."

    # Remove script
    remove_script

    # Show that fsc file was not founded
    show_screen "fsc_not_found.png"

    # Exit
    exit 0
fi

# Mount EFS system in read/write mode
/bin/mount -uw /mnt/efs-system

# check if mme-becker.sh file exist
if test -a /sbin/mme-becker.sh ; then

    # check if second install,
    # test if mme-becker.sh contains "acios_db.ini" string
    XX=`/usr/bin/grep acios_db.ini /sbin/mme-becker.sh`

    if [ ! -z "$XX" ]
    then
        # already installed - uninstall first!
        show_screen "already_installed.png"

        # Show already installed screen
        flog "The activation is already installed"

        # Remove script
        remove_script

        # Exit from script
        exit 0
    fi

    # backup mme-becker.sh for later uninstall
    /bin/cp /sbin/mme-becker.sh /sbin/mme-becker.sh.pre-navdb.bak

    # remove mme-becker launch line
    /usr/bin/sed "/\/sbin\/mme-becker/ d" < /sbin/mme-becker.sh > /sbin/mme-becker.sh.new

    # Move new created file to final file
    /bin/mv /sbin/mme-becker.sh.new /sbin/mme-becker.sh

    # Create mme-becker.sh script
    create_mme_becker "/sbin/mme-becker.sh"

else
    # first install

    # Replaces mme-becker for mme-becker.sh in mmelauncher.cfg file and save the result to a new file
    /usr/bin/sed "s/\/mme-becker$/\/mme-becker.sh/" < /etc/mmelauncher.cfg > /etc/mmelauncher.cfg.new

    # If is the first time we touch the file create a backup
    if ! test -a /etc/mmelauncher.cfg.pre-navdb.bak ; then
        # just keep original version - so just do this the first time
        /bin/mv /etc/mmelauncher.cfg /etc/mmelauncher.cfg.pre-navdb.bak
    fi

    # Move the new created file to original file
    /bin/mv /etc/mmelauncher.cfg.new /etc/mmelauncher.cfg

    # test if mmelauncher.cfg contains "mme-becker.sh" string
    XX=`/usr/bin/grep mme-becker.sh /etc/mmelauncher.cfg`

    # mmelauncher is clean, remove other activator files
    if [ ! -z "$XX" ] ; then
        flog "The mmelauncher.cfg file was successfully modified"
    else
        flog "The mmelauncher.cfg file was not modified"
    fi

    # Create mme-becker.sh file
    create_mme_becker "/sbin/mme-becker.sh"

fi

# Mount EFS persist in read/write mode
mount -uw /mnt/efs-persist/

# Remove all FSC from FSC dir
rm -R -f /mnt/efs-persist/FSC/*

# Copies the SD FSC to FSC dir
cp $dstPath/$FSC /mnt/efs-persist/FSC/$FSC

# Shows final screen
show_screen "installation_successfully.png"

# Write to log
flog "Installation successful"

# Kill navcore process
slay -9 `pidin | grep -i 'navcore'`

# Remove script
remove_script
