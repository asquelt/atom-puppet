# atom-puppet
Install Atom editor as Puppet IDE

# Installation

```
curl --silent --location http://git.io/atom.pp | bash
```

# TODO
- MAC (?)
- WINDOWS (with [chocolatey](https://chocolatey.org/packages/Atom)?)
- APM behind firewall with proxy:
```
cat <<. >>~/.atom/.apmrc
https-proxy = https://9.0.2.1:0
strict-ssl = false
# check: apm config get https-proxy
.
```
