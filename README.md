The XPK package manager
=======================
XPK is a source, and binary based package manager
that aims to be powerful, simple and user friendly

It supports:
1. musl  systems
2. glibc systems
3. XNU/Darwin systems (x86_64)
4. XNU/Darwin systems (arm64)
5. Anything unix-like that is not super-niche

It does not(and probably never will) support:
1. Windows (32bit)
2. Windows (64bit)
3. Windows (arm64)
4. Literally anything that isn't unix-like

License
=======
XPK uses the 2-Clause BSD License. More info about it at: https://opensource.org/license/bsd-2-clause

# Verifying releases

> [!IMPORTANT]
> XPK releases are signed with these keys, for both the core repository
> and the package manager, from now on.

aurelius (xpk maintainer)
--------------------------
    Fingerprint: 7194 59C4 0E06 BCD8 7785 528F 48DC 1015 5AE4 87B5

    Fetch via:
    gpg --keyserver keys.openpgp.org --recv-keys 719459C40E06BCD87785528F48DC10155AE487B5

    Or view directly:
    https://keys.openpgp.org/search?q=719459C40E06BCD87785528F48DC10155AE487B5

firewald (xpk maintainer)
--------------------------------
    Fingerprint: 8617 C568 8597 EF55 23B4  84CB 4CBF 9096 C9F9 19FA

    Fetch via:
    gpg --keyserver keys.openpgp.org --recv-keys 8617C5688597EF5523B484CB4CBF9096C9F919FA

    Or view directly:
    https://keys.openpgp.org/search?q=8617C5688597EF5523B484CB4CBF9096C9F919FA


A release signed by either key should be considered valid. If you
notice a release signed by a key not listed here, treat it as
untrusted and please open an issue, although this shan't happen.

Documentation
=============
At the moment, XPK is not documented.
In the not-so-far future, it will be.
When this will come, the link to the documentation will be put here

Star history
============
<a href="https://www.star-history.com/?repos=fischblob-lol%2Fxpk&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=fischblob-lol/xpk&type=date&theme=dark&legend=bottom-right&sealed_token=JByaEYclA6Eohd-SAgoM5MR2IE8P5tkyuFdSG_6kUQuL_ZzTYGBztUvJjrvYaNNhbAblF-h1Ql3Vsu6aiehxiz3crISQrI9G1DLOelPyiCVeJgCfkUOHVyWcw0oIeAogioWJT2j9jI4u_ZChZSSgX3f3IcTQaBjFPCHGZNg0uyszYp3GNaAK6oZVA3_0" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=fischblob-lol/xpk&type=date&legend=bottom-right&sealed_token=JByaEYclA6Eohd-SAgoM5MR2IE8P5tkyuFdSG_6kUQuL_ZzTYGBztUvJjrvYaNNhbAblF-h1Ql3Vsu6aiehxiz3crISQrI9G1DLOelPyiCVeJgCfkUOHVyWcw0oIeAogioWJT2j9jI4u_ZChZSSgX3f3IcTQaBjFPCHGZNg0uyszYp3GNaAK6oZVA3_0" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=fischblob-lol/xpk&type=date&legend=bottom-right&sealed_token=JByaEYclA6Eohd-SAgoM5MR2IE8P5tkyuFdSG_6kUQuL_ZzTYGBztUvJjrvYaNNhbAblF-h1Ql3Vsu6aiehxiz3crISQrI9G1DLOelPyiCVeJgCfkUOHVyWcw0oIeAogioWJT2j9jI4u_ZChZSSgX3f3IcTQaBjFPCHGZNg0uyszYp3GNaAK6oZVA3_0" />
 </picture>
</a>


notes to future sundowner
=============
tommorow PLEASE add asynchronous downloads.
