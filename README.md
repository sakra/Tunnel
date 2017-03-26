Tunnel
======

Tunnel is a set of scripts that simplify launching remote *Mathematica* kernels where all
established MathLink connections are automatically tunneled through a secure shell connection.

Features
--------

* Supports launching of remote *Mathematica* controller kernels and remote *Mathematica* compute
  kernels.
* MathLink connections to the remote kernel are tunneled over SSH. This simplifies connecting to a
  remote kernel behind a firewall or a NAT router over the Internet.
* Works with Windows, Linux and OS X versions of *Mathematica*.
* Compatible with *Mathematica* versions from 8.0 to 11.0.

Requirements
------------

* A Wolfram [*Mathematica*][wmma] product (*Mathematica*, gridMathematica, Wolfram Finance Platform).
* OpenSSH client and server under Linux and OS X.
* [PuTTY][putty] on a Windows *Mathematica* front end machine.
* An SSH server on a remote Windows *Mathematica* kernel machine. See the [Tunnel manual][manual]
  for a list of supported SSH servers.

Installation
------------

Under Linux or OS X, execute the shell script `install-tunnel.sh` to install the required scripts
to the correct locations for an existing *Mathematica* installation. Under Windows, execute the
batch script `install-tunnel.bat` to install the required scripts.

The Tunnel related scripts can also be installed manually. See the [Tunnel manual][manual] for more
information.

The installation must be performed on both the local machine that runs the *Mathematica* front end,
and on the remote machine that runs the *Mathematica* kernel.

Usage
-----

See the [Tunnel manual][manual] for information on

 * How to set up remote controller kernel configurations using the Tunnel scripts in the
   *Mathematica* front end kernel configuration options dialog.
 * How to set up remote compute kernels with the *Mathematica* Parallel package.
 * Technical background information.

Known Issues
------------

Tunnel enabled remote controller kernel launching no longer works for *Mathematica* 11.1, because
Wolfram has switched to a new method of establishing the parallel links between the front end and
the controller kernel. Tunnel enabled remote compute controller kernel launching works, though.


[manual]:https://github.com/sakra/Tunnel/blob/master/MANUAL.md
[putty]:http://www.chiark.greenend.org.uk/~sgtatham/putty
[wmma]:http://www.wolfram.com/mathematica/
