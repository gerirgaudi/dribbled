# OVERVIEW

*Dribbled* collects and displays information about DRBD devices.

*Dribbled* is available as a Rubygem: [gem install dribbled](https://rubygems.org/gems/dribbled "Dribbled")

# SYNOPSIS

    dribbled [options] <action> [options]

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

With no options or arguments, `dribbled` displays help (as shown above).

# PERSONALITIES

*Dribbled* has two personalities: when run as `dribbled`, it behaves according to the action and parameters used; when run as `check_drbd`, it assumes the `check` action, which enables Nagios plugin behavior.

      gerir@boxie:~:dribbled show
      0     r0 Connected         UpToDate/UpToDate      Secondary/Primary  sourcehost /dev/drbd0    desthost /dev/drbd0
      1     r1 Connected         UpToDate/UpToDate      Secondary/Primary   sourcehost /dev/drbd1   desthost /dev/drbd1
      5     r5 Connected         UpToDate/UpToDate      Secondary/Primary   sourcehost /dev/drbd5   desthost /dev/drbd5
      6     r6 SyncTarget [  4%] Inconsistent/UpToDate  Secondary/Primary   sourcehost /dev/drbd6   desthost /dev/drbd6

      gerir@boxie:~:dribbled check
      warning: 6:cs:SyncTarget[4.6%%];ds:Inconsistent/UpToDate

      gerir@boxie:~:dribbled check
      warning: 6:cs:SyncTarget[4.6%%];ds:Inconsistent/UpToDate

Currently, there is no way to configure what constitutes alert conditions, but generally, a **critical** alert will be generated when a resource is found in non-`Connected` and non-`UpToDate` state,  except when said resource is in `SyncSource`, `SyncTarget`, `VerifyS`, `VerifyT`, `PausedSyncS`, `PausedSyncT`, or `StandAlone` connection state, which causes a **warning**. Also, resources that are `Connected` and `UpToDate` but missing from the configuration will generate a **warning**.

