Tunnel Manual
=============

Tunnel is a set of scripts that simplify launching remote *Mathematica* kernels, where all
established MathLink connections are automatically tunneled through a secure shell connection.

Tunnel is an improved version of the [Remote Kernel Strategies][remote_kernel_strategies] solution
originally presented at the *Mathematica* User Conference 2008. The new version contains
compatibility fixes for newer versions of *Mathematica* and also supports remote compute kernels.

Beginning with *Mathematica* version 10, MathLink has been rebranded as [WSTP][wstp]. This manual
sticks with the name MathLink.

Features
--------

* Supports launching of remote *Mathematica* controller kernels from the *Mathematica* front end.
* Supports launching remote *Mathematica* compute kernels with the Parallel package.
* MathLink connections to the remote kernel are tunneled over SSH. This simplifies connecting to a
  remote kernel behind a firewall or a NAT router over the Internet.
* Works with Windows, Linux and OS X versions of *Mathematica*.
* Compatible with *Mathematica* versions from 8.0 to 11.0.

Requirements
------------

* A Wolfram [*Mathematica*][wmma] product (Mathematica, gridMathematica, Wolfram Finance Platform).
* OpenSSH client and server under Linux and OS X.
* [PuTTY][putty] on a Windows *Mathematica* front end machine.
* An SSH server on a remote Windows *Mathematica* kernel machine (see below).

Installation
------------

### Script-aided Installation

Execute the shell script `install-tunnel.sh` under Linux or OS X to install the required scripts
to the correct locations for an existing *Mathematica* installation. Under Windows, execute the
batch script `install-tunnel.bat` to install the required scripts.

The installation must be performed on both the local machine that runs the *Mathematica* front end,
and on the remote machine that runs the *Mathematica* kernel.

### Manual Installation

The file `tunnel.m` needs to be installed on the remote *Mathematica* kernel machine. It needs to
be placed into the `Kernel` sub-directory of the *Mathematica* base directory. To determine the
Mathematica base directory evaluate the expression `$BaseDirectory` in a *Mathematica* session.
E.g., under OS X launch Terminal.app and run:

    $ /Applications/Mathematica.app/Contents/MacOS/MathKernel
    Mathematica 10.1.0 for Mac OS X x86 (64-bit)
    Copyright 1988-2015 Wolfram Research, Inc.

    In[1]:= $BaseDirectory
    Out[1]= /Library/Mathematica

`$BaseDirectory` usually evaluates to `C:\ProgramData\Mathematica` under Windows 7, to
`/Library/Mathematica` under OS X and to `/usr/share/Mathematica` under Linux.

The accompanying script files `tunnel.sh` and `tunnel_sub.sh` (or `tunnel_sub.bat` and `tunnel.bat`
for Windows) need to be installed on the local *Mathematica* front end machine. They need to be
placed in the `FrontEnd` sub-directory of the *Mathematica* user-specific base directory.
To determine the *Mathematica* user-specific base directory evaluate the *Mathematica* expression
`$UserBaseDirectory` in a *Mathematica* session. E.g., under Windows launch cmd.exe and run:

    C:\>"C:\Program Files\Wolfram Research\Mathematica\10.1\math.exe"
    Mathematica 10.1.0 for Microsoft Windows (64-bit)
    Copyright 1988-2015 Wolfram Research, Inc.

    In[1]:= $UserBaseDirectory
    Out[1]= C:\Users\sakra\AppData\Roaming\Mathematica

`$UserBaseDirectory` usually evaluates to `C:\Users\user_name\AppData\Roaming\Mathematica` under
Windows, to `~/Library/Mathematica` under OS X and to `~/.Mathematica` under Linux.

Under Linux and OS X make sure to check that the executable bit of the copied scripts `tunnel.sh`
and `tunnel_sub.sh` is set.

Setup
-----

Tunnel requires setting up third party software on both the local front end machine and on the
remote kernel machine.

### Linux

Install OpenSSH client on the local front end machine:

    sudo apt-get install openssh-client

Install and start OpenSSH server on the remote kernel machine:

    sudo apt-get install openssh-server

To make OpenSSH work, additional configuration may be required depending on the Linux distribution
used.

### OS X

OpenSSH is installed under OS X out-of-the-box. On a remote OS X kernel machine, start the OpenSSH
server by enabling Remote Login in the Sharing panel of the System Preferences application.

### Windows

Install [PuTTY][putty] on the local front end machine.

On the remote kernel machine an SSH server needs to be installed. Tunnel has been tested with the
following third party SSH server software:

  * [Bitvise SSH Server][winsshd]
  * [Cygwin][cygwin] OpenSSH is a heavy weight solution that you should only consider, if you are
    comfortable with a POSIX shell environment.

Configuration of Remote Controller Kernels
------------------------------------------

### Programmatic Configuration

Normally kernel configurations need to be defined interactively in the *Mathematica* front end's
Kernel Configuration Options dialog accessible from the `Evaluation` menu. The Tunnel package
comes with a convenience function `SetupTunnelKernelConfiguration`, which helps you set up
persistent controller kernel configurations programmatically. The function automatically handles
all the nasty details (e.g., MathLink options, kernel file path and quoting) correctly.

In the *Mathematica* front end, first load the `tunnel.m` script:

    In[1]:= Get["tunnel.m"]

Then call `SetupTunnelKernelConfiguration` with a title and a remote host specification:

    In[2]:= SetupTunnelKernelConfiguration["Example","john@host.example.com",
             "OperatingSystem"->"Windows", "VersionNumber"->10.1]
    New configuration "Example" added to kernel configuration options.
    Out[2]= Example->{
              RemoteMachine->True,
              TranslateReturns->True,
              AppendNameToCellLabel->True,
              AutoStartOnLaunch->False,
              MLOpenArguments->-LinkMode Listen -LinkProtocol TCPIP -LinkOptions MLDontInteract -LinkHost 127.0.0.1,
              LoginScript->"`userbaseDirectory`/FrontEnd/tunnel.sh" "john@host.example.com" "C:\Program Files\Wolfram Research\Mathematica\10.1\WolframKernel.exe" "`linkname`"
            }

The command returns the properties of the newly generated configuration. As a side effect, a
persistent kernel configuration is created in the front end settings, as shown in the following
snapshot:

![](https://github.com/sakra/Tunnel/blob/master/images/kernel_configuration.png)

If a persistent kernel configuration already exists under the given title, its properties are
updated.

The remote host specification uses the syntax `[user[:password]@]remote_machine[:port]`.
Valid examples are `192.168.1.10:2222`, `john@host.local` or `john:123456@host.example.com`.

If the password is not specified as part of the remote host specification, the SSH server on the
remote kernel machine has to be configured to allow for password-less SSH logins. You may also need
to run an SSH authentication agent (e.g., ssh-agent or Pageant) on the local front end machine.

`SetupTunnelKernelConfiguration` supports the following options:

* `"OperatingSystem"` specifies the operation system of the remote controller kernel. Possible
values are `"Windows"`, `"MacOSX"` or `"Unix"`. If omitted, it defaults to the operation system of
the *Mathematica* front end.
* `"VersionNumber"` is a real number which specifies the remote controller kernel version number.
It defaults to the version number of the *Mathematica* front end.
* `"KernelPath"` specifies the full path to the controller kernel on the remote machine.
If omitted, it is initialized to the default installation path of the *Mathematica* kernel,
depending on the given operating system and version number.

### Interactive Configuration

To set up launching of a remote *Mathematica* controller kernel with Tunnel in the *Mathematica*
front end interactively, choose the menu command `Kernel Configuration Options...` from the
`Evaluation` menu and create a new kernel configuration. In the kernel configuration dialog
activate the `Advanced Options` and configure the two text boxes below as follows.

Arguments To MLOpen:

    -LinkMode Listen -LinkProtocol TCPIP -LinkOptions MLDontInteract -LinkHost 127.0.0.1

Launch command:

Depending on the operating system used on the local front end machine and on the remote controller
kernel machine, choose the appropriate command from below. Replace the example remote host
specification `john@host.example.com` with your actual remote host. The path to the *Mathematica*
kernel may need adjustment, if you use a *Mathematica* version different from 10.1.

Local Linux or OS X front end and remote Linux controller kernel:

    "`userbaseDirectory`/FrontEnd/tunnel.sh" "john@host.example.com" "/usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel" "`linkname`"

Local Linux or OS X front end and remote OS X controller kernel:

    "`userbaseDirectory`/FrontEnd/tunnel.sh" "john@host.example.com" "/Applications/Mathematica.app/Contents/MacOS/MathKernel" "`linkname`"

Local Linux or OS X front end and remote Windows controller kernel:

    "`userbaseDirectory`/FrontEnd/tunnel.sh" "john@host.example.com" "C:\Program Files\Wolfram Research\Mathematica\10.1\math.exe" "`linkname`"

Local Windows front end and remote Linux controller kernel:

    "`userbaseDirectory`\FrontEnd\tunnel.bat" "john@host.example.com" "/usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel" "`linkname`"

Local Windows front end and remote OS X controller kernel:

    "`userbaseDirectory`\FrontEnd\tunnel.bat" "john@host.example.com" "/Applications/Mathematica.app/Contents/MacOS/MathKernel" "`linkname`"

Local Windows front end and remote Windows controller kernel:

    "`userbaseDirectory`\FrontEnd\tunnel.bat" "john@host.example.com" "C:\Program Files\Wolfram Research\Mathematica\10.1\math.exe" "`linkname`"

Note that `userbaseDirectory` and `linkname` must be entered verbatim. For controller kernels
`userbaseDirectory` will be automatically replaced with the path to the user-specific *Mathematica*
base directory. `linkname` will be replaced with the name of the main link created by the front end
upon connecting.

The remote host specification uses the syntax `[user[:password]@]remote_machine[:port]`.
Valid examples are `192.168.1.10:2222`, `john@host.local` or `john:123456@host.example.com`.

Configuration of Remote Compute Kernels
---------------------------------------

The Wolfram Language supports different connection methods for compute kernels. See the page
[Launching and Connecting][connectionmethods] for more information. The Tunnel package adds a
new method `RemoteMachineTunnel`.

### Connection Method `RemoteMachineTunnel`

`RemoteMachineTunnel` acts as a thin wrapper around the existing `RemoteMachine` connection method
and takes care of handling all the nasty details (e.g., MathLink options, kernel file path and
quoting) of launching remote compute kernels correctly.

To make use of the connection method `RemoteMachineTunnel`, first load the `RemoteKernels` package
in a *Mathematica* session:

    In[1]:= Needs["SubKernels`RemoteKernels`"]

Then load the `tunnel.m` script, which defines `RemoteMachineTunnel`:

    In[2]:= Get["tunnel.m"]

`RemoteMachineTunnel` needs a remote host specification, the number of compute kernels to launch
and options:

    In[3]:= kernels=RemoteMachineTunnel["john@host.example.com", 2, "OperatingSystem"->"Unix"]
    Out[3]= <<2 kernels on host.example.com>>

The remote host specification uses the syntax `[user[:password]@]remote_machine[:port]`.
Valid examples are `192.168.1.10:2222`, `john@host.local` or `john:123456@host.example.com`.

Then, to launch the remote compute kernels through an SSH tunnel, enter:

    In[4]:= LaunchKernels[kernels]
    Out[4]= {KernelObject[1, "host.example.com"], KernelObject[2, "host.example.com"]}

`RemoteMachineTunnel` supports the following options:

* `"OperatingSystem"` specifies the operation system of the remote compute kernel. Possible
values are `"Windows"`, `"MacOSX"` or `"Unix"`. If omitted, it defaults to the operation system of
the *Mathematica* controller kernel.
* `"VersionNumber"` is a real number which specifies the remote compute kernel version number.
It defaults to the version number of the *Mathematica* controller kernel.
* `"KernelPath"` specifies the full path to the compute kernel on the remote machine. If omitted,
it is initialized to the default installation path of the *Mathematica* kernel, depending on the
given operating system and version number.

### Connection Method `RemoteMachine`

To set up a remote compute kernel without the aid of the `RemoteMachineTunnel` method, use the
configuration features of the built-in `RemoteMachine` method in the following way:

First load the `RemoteKernels` package in a *Mathematica* session:

    Needs["SubKernels`RemoteKernels`"]

Depending on the operating system used on the controller kernel machine and on the remote compute
kernel machine, choose the appropriate command from below. The path to the *Mathematica* kernel may
need adjustment, if you use a *Mathematica* version different from 10.1.

Linux or OS X controller kernel and remote Linux compute kernel:

    $RemoteCommand = "\"" <> $UserBaseDirectory <>
        "/FrontEnd/tunnel_sub.sh\" \"`1`\" \"/usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel\" \"`2`\""

Linux or OS X controller kernel and remote OS X compute kernel:

    $RemoteCommand = "\"" <> $UserBaseDirectory <>
        "/FrontEnd/tunnel_sub.sh\" \"`1`\" \"/Applications/Mathematica.app/Contents/MacOS/MathKernel\" \"`2`\""

Linux or OS X controller kernel and remote Windows compute kernel:

    $RemoteCommand = "\"" <> $UserBaseDirectory <>
        "/FrontEnd/tunnel_sub.sh\" \"`1`\" \"C:\\Program Files\\Wolfram Research\\Mathematica\\10.1\\math.exe\" \"`2`\""

Windows controller kernel and remote Linux compute kernel:

    $RemoteCommand = "\"\"" <> $UserBaseDirectory <>
        "\\FrontEnd\\tunnel_sub.bat\" \"`1`\" \"/usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel\" \"`2`\"\""

Windows controller kernel and remote OS X compute kernel:

    $RemoteCommand = "\"\"" <> $UserBaseDirectory <>
        "\\FrontEnd\\tunnel_sub.bat\" \"`1`\" \"/Applications/Mathematica.app/Contents/MacOS/MathKernel\" \"`2`\"\""

Windows controller kernel and remote Windows compute kernel:

    $RemoteCommand = "\"\"" <> $UserBaseDirectory <>
        "\\FrontEnd\\tunnel_sub.bat\" \"`1`\" \"C:\\Program Files\\Wolfram Research\\Mathematica\\10.1\\math.exe\" \"`2`\"\""

For compute kernels, the slot `1` in `$RemoteCommand` will be replaced with the machine
specification given in a `RemoteMachine` expression. The slot `2` will be replaced with the name of
the MathLink endpoint created by the controller kernel upon launching the compute kernel.

If necessary, increase the remote compute kernel connection timeout (the default of 15 seconds may
be too short for slow connections):

    Parallel`Settings`$MathLinkTimeout = 30;

Then, to launch a remote compute kernel, enter:

    kernel = RemoteMachine["john@host.example.com", LinkHost->"127.0.0.1"]
    LaunchKernels[kernel]

Replace the example remote host specification `john@host.example.com` with your actual remote host.

Alternatively, the template command in `$RemoteCommand` can also be specified as part of the
`RemoteMachine` specifier:

    kernel = RemoteMachine["john@host.example.com",
        "\"" <> $UserBaseDirectory <>
        "/FrontEnd/tunnel_sub.sh\" \"`1`\" \"/usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel\" \"`2`\"",
        LinkHost->"127.0.0.1"]
    LaunchKernels[kernel]

Using a Jump Host
-----------------

Under Linux and OS X, Tunnel also supports launching a *Mathematica* kernel on a remote machine
through an [SSH jump host][jumphost].

In the OpenSSH configuration file `~/.ssh/config` on the local front end machine, add a `Host`
configuration that specifies a `ProxyCommand` to forward SSH traffic to the actual remote
*Mathematica* kernel machine:

    Host jumphost.example.com
        HostName math.example.com
        ProxyCommand ssh jumphost.example.com -q -W %h:%p

Then set up a controller kernel configuration for `jumphost.example.com`:

    In[1]:= Get["tunnel.m"]
    In[2]:= SetupTunnelKernelConfiguration["MathJump","john@jumphost.example.com",
             "OperatingSystem"->"Unix"]

Also note that the OpenSSH option `AllowTcpForwarding` must be set to `Yes` in the `sshd`
config file (usually `/etc/sshd_config`) on the jump host machine. See the
[sshd_config man page][sshd_config] for more information.

Troubleshooting
---------------

First, double-check that the Tunnel scripts are correctly installed on both the local front end
and on the remote kernel machine.

If the *Mathematica* front end machine runs Linux or OS X, double-check that the executable bit of
the scripts `tunnel.sh` and `tunnel_sub.sh` is set.

If connecting to the remote kernel from the *Mathematica* front end with Tunnel does not succeed,
it is a good idea to check if a remote *Mathematica* kernel can be launched from the command line.

Under Linux or OS X, use the OpenSSH client `ssh` to try to connect to the remote machine:

    $ ssh john@host.example.com /usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel
    Mathematica 10.1.0 for Linux x86 (64-bit)
    Copyright 1988-2015 Wolfram Research, Inc.

Under Windows, use the PuTTY command line tool `plink` to try to connect to the remote machine:

    C:\>plink john@host.example.com /usr/local/Wolfram/Mathematica/10.1/Executables/MathKernel
    Mathematica 10.1.0 for Linux x86 (64-bit)
    Copyright 1988-2015 Wolfram Research, Inc.

As before, the remote host specification and the remote kernel path must adapted to your actual
environment.

Often it is sufficient to establish the connection once from the command line to make SSH remember
the host key of the remote machine.

For troubleshooting purposes, the tunnel script files generate a separate log file in the directory
`$UserBaseDirectory/FrontEnd/Logs` for each invocation.

If you are using OpenSSH on the server side, it may be helpful to temporarily increase the log
level of `sshd`. Open the `sshd` config file (usually `/etc/sshd_config`), locate the setting for
`LogLevel`, then change it to

    LogLevel DEBUG3

and restart `sshd`. The level `DEBUG3` gives you detailed information about the commands sent by
the SSH client in the sshd log file.

Technical Background
--------------------

### Remote Controller Kernel Launching (Version 6 to Version 11.0)

Starting with *Mathematica* version 6, the front end and controller kernel communicate with each
other through several MathLink connections, known as the main link, the preemptive link and the
service link. The documentation page on [Advanced Dynamic Functionality][dynamic] gives more
information on the purpose of each link.

If the controller kernel and the front end run on different machines, the MathLink TCPIP protocol
is used for those links. Each TCPIP link requires two open TCP/IP channels between the local
machine and the remote machine. One channel functions as the primary data stream and the second
channel functions as the urgent message channel.

When a remote controller kernel is started from the front end, the main link is established as a
callback connection from the kernel machine to the front end machine. Then, during startup the
kernel sets up the preemptive and the service link as listening links by calling the function
`CreateFrontEndLink` for both links. The front end then establishes connections to both links.

In order for the front end to properly connect to the remote controller kernel with tunneling of
the MathLink connections, SSH port forwarding has to be configured for each one of the six
TCP/IP channels. The TCP/IP ports used for the main link are forwarded from the remote kernel
machine to the local front end machine. Forwarding the TCP/IP channels of the preemptive and the
service link is more tricky. The kernel init file `tunnel.m` replaces the built-in function
`CreateFrontEndLink` with an alternate implementation that makes the kernel use in-advance
forwarded TCP/IP ports for the TCP/IP channels of the preemptive and the service link.

### Remote Compute Kernel Launching

A controller kernel and a remote compute kernel communicate with each other through one MathLink
connection. When a remote compute kernel is launched, this link is established as a callback
connection from the compute kernel machine to the controller kernel machine.

The tunnel script takes care of forwarding the TCP/IP channels used for this link from the remote
compute kernel machine to the controller kernel machine. Installing the kernel init file `tunnel.m`
is not a requirement for remote compute kernel launching.

Known Issues
------------

Tunnel enabled remote controller kernel launching no longer works for *Mathematica* 11.1, because
Wolfram has switched to a new method of establishing the parallel links between the front end and
the controller kernel. Tunnel enabled remote compute controller kernel launching works, though.

[connectionmethods]:http://reference.wolfram.com/language/ParallelTools/tutorial/ConnectionMethods.html
[cygwin]:https://www.cygwin.com/
[dynamic]:http://reference.wolfram.com/language/tutorial/AdvancedDynamicFunctionality.html
[freesshd]:http://www.freesshd.com/
[jumphost]:https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Proxies_and_Jump_Hosts#Passing_Through_One_or_More_Gateways_Using_ProxyJump
[putty]:http://www.chiark.greenend.org.uk/~sgtatham/putty
[remote_kernel_strategies]:http://library.wolfram.com/infocenter/Conferences/7250/
[sshd_config]:http://www.manpagez.com/man/5/sshd_config/
[winsshd]:http://www.bitvise.com/ssh-server-download
[wmma]:http://www.wolfram.com/mathematica/
[wstp]:https://reference.wolfram.com/language/guide/WSTPAPI.html
