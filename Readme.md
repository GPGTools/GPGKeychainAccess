GPG Keychain Access
===================

GPG Keychain Access is used to create and manage GnuPG keys.

Updates
-------

The latest releases of GPG Keychain Access can be found on our [official website](https://gpgtools.org/).

For the latest news and updates check our [Twitter](https://twitter.com/gpgtools).

Visit our [support page](http://support.gpgtools.org) if you have questions or need help setting up your system and using GPG Keychain Access.

If you are a developer, feel free to have a look at the [open issues](https://gpgtools.lighthouseapp.com/projects/65684).

Localizations are done on [Transifex](https://www.transifex.com/projects/p/GPGKeychainAccess/).


Build
-----

### Clone the repository
```bash
git clone https://github.com/GPGTools/GPGKeychainAccess.git
cd GPGKeychainAccess
```

### Build
```bash
make
```

### Install
To copy GPG Keychain Access into the Applications folder.
```bash
make install
```

### More build commands
```bash
make help
```

Don't forget to install [MacGPG2](https://github.com/GPGTools/MacGPG2)
and [Libmacgpg](https://github.com/GPGTools/Libmacgpg).  
Enjoy your custom GPG Keychain Access.


System Requirements
-------------------

* Mac OS X >= 10.6
* Libmacgpg
* GnuPG
