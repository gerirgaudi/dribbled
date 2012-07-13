# OVERVIEW

*Dribbled* collects and displays information about [DRBD](http://www.drbd.org/home/what-is-drbd/ "DRBD") devices.

*Dribbled* is available as a Rubygem: [gem install dribbled](https://rubygems.org/gems/dribbled "Dribbled")

# SYNOPSIS

    dribbled [options] <action> [options]
    
Actions are one of `show`, `check`, `snap`.

Options are as follows:

	General options:
        -D, --drbdadm DRBDADM            Path to drbdadm binary
        -P, --procdrbd PROCDRBD          Path to /proc/drbd
        -X, --xmldump XMLDUMP            Path to output for drbdadm --dump-xml
        -H, --hostname HOSTNAME          Hostname
        -d, --debug                      Enable debug mode
        -a, --about                      Display dribbled information
        -V, --version                    Display dribbled version
            --help                       Show this messageSenedsa options

With no options or arguments, `dribbled` displays help as shown above (unless called as `check_drbd`; see _Personalities_).

# PERSONALITIES

*Dribbled* has two personalities: when run as `dribbled`, it behaves according to the action and parameters used; when run as `check_drbd`, it assumes the `check` action, which enables Nagios plugin behavior. (i.e., `dribbled check` is equivalent to `check_drbd`).

# ACTIONS

## Show

The `show` action displays information about DRBD devices in the system. This action currently accepts no options.

      gerir@boxie:~:dribbled show
      0     r0 Connected         UpToDate/UpToDate      Secondary/Primary   sourcehost /dev/drbd0   desthost /dev/drbd0
      1     r1 Connected         UpToDate/UpToDate      Secondary/Primary   sourcehost /dev/drbd1   desthost /dev/drbd1
      5     r5 Connected         UpToDate/UpToDate      Secondary/Primary   sourcehost /dev/drbd5   desthost /dev/drbd5
      6     r6 SyncTarget [  4%] Inconsistent/UpToDate  Secondary/Primary   sourcehost /dev/drbd6   desthost /dev/drbd6

## Check

The `check` action enables Nagios plugin mode, in which a single line of output is produced on `STDOUT` with the status of the devices.

      gerir@boxie:~:dribbled check
      warning: 6:cs:SyncTarget[4.6%%];ds:Inconsistent/UpToDate

      gerir@boxie:~:dribbled check
      warning: 6:cs:SyncTarget[4.6%%];ds:Inconsistent/UpToDate

Currently, there is no way to configure what constitutes alert conditions, but generally, a **critical** alert will be generated when a resource is found in non-`Connected` and non-`UpToDate` state,  except when said resource is in `SyncSource`, `SyncTarget`, `VerifyS`, `VerifyT`, `PausedSyncS`, `PausedSyncT`, or `StandAlone` connection state, which causes a **warning**. Also, resources that are `Connected` and `UpToDate` but missing from the configuration will generate a **warning**.

Both active and passive modes are supported, with the corresponding options:

        Check Options
        -M, --monitor [nagios]           Monitoring system
        -m, --mode [active|passive]      Monitoring mode
        -H, --nsca_hostname HOSTNAME     NSCA hostname to send passive checks
        -c, --config CONFIG              Path to Senedsa (send_nsca) configuration
        -S, --svc_descr SVC_DESR         Nagios service description
        -h, --hostname HOSTNAME          Service hostname

As `dribbled` uses [Senedsa](https://github.com/evernote/ops-senedsa "Senedsa"), configurations files are supported.

## Snap

The `snap` action is useful to capture raw data DRBD from a system for test and development. It produces two files, `xmldump.`_suffix_ and `proddrbd.`_suffix_:

    Snap Options
    -S, --suffix SUFFIX              Suffix (defaults to PID)
    -D, --directory DIRECTORY        Directory (defaults to /tmp)
    
These files can then be used with the general `--procdrbd PROCDRBD` and `--xmldump XMLDUMP` options:

	gerir@boxie:~/dribbled -P data/procdrbd.wfconnection -X data/xmldump.wfconnection -H sourcehost show
	 0  r0 Connected     UpToDate/UpToDate   Primary/Secondary   sourcehost /dev/drbd0   desthost /dev/drbd0 
 	 1  r1 Connected     UpToDate/UpToDate   Primary/Secondary   sourcehost /dev/drbd1   desthost /dev/drbd1 
	12 r12 Connected     UpToDate/UpToDate   Primary/Secondary   sourcehost /dev/drbd12  desthost /dev/drbd12
	13 r13 WFConnection  UpToDate/DUnknown   Primary/Unknown

We use the general `-H` option to let `dribbled` know which host the commands were captured on (so that it can properly identify source and destination).
	                                                                                            