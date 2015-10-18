## 1.1.2 (2015-10-18)

* *Mathematica* 10.3 compatibility.
* fix bug with handing of missing evaluator settings in `SetupTunnelKernelConfiguration`.
* when using OpenSSH, set option `ServerAliveInterval` to keep connection alive.

## 1.1.1 (2015-08-04)

* add work-around for `SystemFiles/Libraries/libcrypto.so` incompatibility with `/usr/bin/ssh` under Linux.

## 1.1.0 (2015-07-25)

* use WSTP instead of MathLink for *Mathematica* 10 or later.
* add *Mathematica* 10.2 support.
* add function `SetupTunnelKernelConfiguration` for easy setting up of remote controller kernel configurations.
* add function `RemoteMachineTunnel` for easy configuration of tunneled remote compute kernels.
* enable SSH agent forwarding in SSH connection.
* manual updates.

## 1.0.0 (2015-06-07)

* first release.
