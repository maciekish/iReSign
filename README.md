# Introduction #

iReSign allows iDevice app bundles (.ipa) files to be signed or resigned with a digital certificate from Apple for distribution. This tool is aimed at enterprises users, for enterprise deployment, when the person signing the app is different than the person(s) developing it.

## Requirements ##

- Mac OS 10.5+

- A certificate issued by Apple.

- Apple _applewwcdr_ intermediate certificate must be trusted.

- Xcode *latest* version for your OS (please).

The *codesign* tool needs *codesign_allocate* (contained within Xcode itself) in order to perform the re-signing process and validating the result correctly. To ensure this is done, execute the following commands:

```
sudo mv /usr/bin/codesign_allocate /usr/bin/codesign_allocate_old
sudo ln -s /Applications/Xcode.app/Contents/Developer/usr/bin/codesign_allocate /usr/bin
```

Executing */usr/bin/codesign_allocate* should report:

```
Usage: /usr/bin/codesign_allocate -i input [-a <arch> <size>]... [-A <cputype> <cpusubtype> <size>]... -o output
```

Once this is in place, you should be able to re-sign applications with the iReSign tool without any issues.


## iReSign is NOT intended for piracy. Issues about piracy will be ignored.##

*The name iReSign is Copyright ©2010 Maciej Swic. All rights reserved.*
