# Transparent Git Encryption

This project based(forked) on [git-encrypt][8] by Woody Gilk(@shadowhand) but diverged and hard to
merge back. It has own uniq features.
The original gitcrypt tool is inspired by [this document][1] written by [Ning Shang][2],
which was in turn inspired by [this post][3]. Without these two documents,
by people much smarter than me, gitcrypt would not exist.

> There is [some controversy][4] over using this technique, so do your research
and understand the implications of using this tool before you go crazy with it.

## Features

* Using strong master key to encrypt data.

* Master key can be encrypted/decrypting through such facilities:

  * *GPG*. The most secure way because master key not stored anywhere unencrypted. It has some performance issue because of decrypting is made on ANY FILE while commit/checkout/stage/diff/merge. Also it is possible to encrypt master key for multiple users(which PUBLIC keys you have) and can be used in multiuser encrypted repo.

  * *passphrase*. The master key is decrypted once on repo initialization and stored in .git/config.

  * *SSH private-key*. It is suitable ONLY for personal use because ssh-private key is used to encrypt/decrypt master key. There is no public/private facility used but master key is encrypted with *sha512* hash of ssh-private key internals(decrypted if needed). The master key is decrypted once on repo initialization and stored in .git/config. _This made for users who has ssh-key but no gpg key_

* It possible to merge(and resolve conflicts) in encrypted commits. It is realized by custom merge driver "gitcrypt-merge"

* You can encrypt previous repo history with command1:

		$ gitcrypt crypthistory
		$ You MUST run 'crypthistory' BEFORE any encrypted commits.Do you want to recrypt all history? This may corrut your data? [Y/n]
		...
    
* You can encrypt/decrypt all history:

		$ gitcrypt crypthistory
		$ gitcrypt decrypthistory
    
* You can enable/disable gitcrypt facility:

		$ gitcrypt disable
		$ gitcrypt reset
		$ gitcrypt enable
		$ gitcrypt reset
    
* You can add multiple users to allowed to encrypt master key when using GPG:

		$ gitcrypt init
		$ Please select masterkey encryption type:
		$ type 'gpg' for use gpg
		$ type path to ssh-private key ex: ~/.ssh/id_rsa
		$ or type <passphrase> wich will encrypt masterkey
		$ *gpg*
		...
		$
		$ You did not specify a user ID. (you may use "-r")
		$ 
		$ Current recipients:
		$ 2048R/DEFD08C4 2015-01-13 "Samoilenko Yuri <kinnalru@gmail.com>"
		$ 
		$ Enter the user ID.  End with an empty line: gitcrypt@gmail.com
		$ 
		$ Current recipients:
		$ 2048R/370F9A12 2015-05-30 "gitcrypt <gitcrypt@gmail.com>"
		$ 2048R/DEFD08C4 2015-01-13 "Samoilenko Yuri <kinnalru@gmail.com>"
		$
		$ Enter the user ID.  End with an empty line: 
		...

    Now kinnalru@gmail.com and gitcrypt@gmail.com can decrypt repo with own private gpg key.


## Requirements
Openssl and git must be installed and the binary must be available in your $PATH.

## Installation

Clone gitcrypt somewhere on your local machine:

		$ git clone https://github.com/kinnalru/gitcrypt
		$ cd gitcrypt

The `gitcrypt` command must be executable:

		$ chmod 0755 gitcrypt

And it and it's internal files must be accessible in your `$PATH`:

		$ export PATH="$PATH:$(pwd)"

### Gentoo

Or you can use my home little overlay for Gentoo: https://github.com/kinnalru/hoverlay

### For Windows

**Verified on PortableGit Only !**

Copy the file gitcrypt to your PortableGit/bin location. In my environment PortableGit is
available at E:\PortableGit. 

> copy gitcrypt E:\PortableGit\bin

Also make sure that PATH environment variable has E:\PortableGit\bin 
available in it.

> Path=C:\Python27\;C:\Python27\Scripts;E:\PortableGit\bin;E:\PortableGit\libexec\git-core;C:\windows\system32;C:\windows\;C:\window
> s\system32\WBEM;c:\windows\System32\WindowsPowerShell\v1.0\;c:\i386\~configs;C:\Users\VKHANORK\AppData\Roaming\Python\Scripts


## Configuration

To quickly setup gitcrypt interactively, run `gitcrypt init` from the root
of your git repository. It will ask you for an encrypt facility GPG/SSH/passphrase,
cipher mode, and what files should be encrypted.

		$ cd my-repo
		$ gitcrypt init

Useful example to mark *.skip files not-encryptable:

		$ cat .git/info/attributes
		$ * filter=encrypt diff=encrypt merge=encrypt
		$ .gitcryptsecret filter diff merge text
		$ .gitattributes filter diff merge text
		$ *.skip text diff merge filter
		$ [merge]
		$    renormalize=true


Your repository is now set up! Any time you `git add` a file that matches the
filter pattern the `clean` filter is applied, automatically encrypting the file
before it is staged. Using `git diff` will work normally, as it automatically
decrypts file content as necessary.

### Manual Configuration

You can manually modify .git/config file:

		$ [gitcrypt]
		$   cipher = aes-256-cbc
		$   pass = gpg           # if gpg used
		$   pass = ~/.ssh/id_rsa # if ssh-private key used
		$   pass =               # empty if passphrase used
		$   secret =             # empty if gpg used 
		$   secret ="hnlR6m#sQY02HcD^22)k0EhMpf&SF*fxY&i4j0gCMdRKuVuI"
		$   salt = 7214e82f24d5511d
		$ [filter "encrypt"]
		$   smudge = gitcrypt smudge
		$   clean = gitcrypt clean
		$ [diff "encrypt"]
		$   textconv = gitcrypt diff
		$ [merge "encrypt"]
		$   name = gitcrypt merge driver
		$   driver = gitcrypt-merge %A %O %B %L


Next, you need to define what files will be automatically encrypted using the
[.git/info/attributes][6] file. Any file [pattern format][7] can be used here.

To encrypt all the files in the repo:

		* filter=encrypt diff=encrypt merge=encrypt
		[merge]
			renormalize = true

To encrypt only one file, you could do this:

		secret.txt filter=encrypt diff=encrypt merge=encrypt

Or to encrypt all ".secure" files:

		*.secure filter=encrypt diff=encrypt merge=encrypt

> If you want this mapping to be included in your repository, use a
`.gitattributes` file instead and **do not** encrypt it.


## Decrypting Clones

To set up decryption from a clone, you will need to repeat the same setup on
the new clone.

First, clone the repository, but **do not perform a checkout**:

		$ git clone -n git://github.com/johndoe/encrypted.get
		$ cd encrypted

> If you do a `git status` now, it will show all your files as being deleted.
Do not fear, this is actually what we want right now, because we need to setup
gitcrypt before doing a checkout.

Now you can either run `gitcrypt init` or do the same manual configuration that
performed on the original repository.

Once configuration is complete, reset and checkout all the files:

		$ gitcrypt reset

All the files in the are now decrypted and ready to be edited.


**Note that if you have diffrent salt you will see that files _modified_ but `git diff` show none.
This will lead to *grown up* of repository because all encrypred files will considered as changed**

# Conclusion

Enjoy your secure git repository! 

[1]: http://syncom.appspot.com/papers/git_encryption.txt "GIT transparent encryption"
[2]: http://syncom.appspot.com/
[3]: http://git.661346.n2.nabble.com/Transparently-encrypt-repository-contents-with-GPG-td2470145.html "Web discussion: Transparently encrypt repository contents with GPG"
[4]: http://article.gmane.org/gmane.comp.version-control.git/113221 "Junio Hamano does not recommend this technique"
[5]: http://en.wikipedia.org/wiki/Cipher
[6]: http://www.kernel.org/pub/software/scm/git/docs/gitattributes.html
[7]: http://www.kernel.org/pub/software/scm/git/docs/gitignore.html#_pattern_format
[8]: http://github.com/shadowhand/git-encrypt
