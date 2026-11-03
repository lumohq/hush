# Third-party notices

Hush is free software under the GNU General Public License v3.0 (see
`LICENSE`). It includes the third-party components below, each under its own
license. The app shows this file under Home › About & licenses.

| Component | Used for | License |
|---|---|---|
| SafariConverterLib (AdGuard) | Converting filter lists into Safari rules | GPL-3.0 |
| PunycodeSwift (Gumob) | Internationalised domain names, used by SafariConverterLib | MIT |
| swift-psl (Andrey Meshkov) | Public Suffix List lookups, used by SafariConverterLib | MIT |
| Public Suffix List data (Mozilla) | Built into swift-psl | MPL-2.0 |
| Fluent Emoji (Microsoft) | 3D icons | MIT |

Filter lists (AdGuard, EasyList, Peter Lowe's list and others) are not part
of the app. Hush downloads them from their publishers at runtime, and each
remains under its publisher's license.

---

## SafariConverterLib

https://github.com/AdguardTeam/SafariConverterLib (version 4.3.1)

Copyright © AdGuard Software Ltd. Licensed under the GNU General Public
License v3.0; the full text is in `LICENSE`. Hush uses it unmodified.

---

## PunycodeSwift

https://github.com/gumob/PunycodeSwift (version 3.0.0)

```
MIT License

Copyright (c) 2018 Gumob

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## swift-psl

https://github.com/ameshkov/swift-psl (version 1.1.188)

```
Copyright 2025 Andrey Meshkov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Public Suffix List

https://publicsuffix.org, compiled into swift-psl's resources.

The Public Suffix List is maintained by Mozilla and its contributors and is
licensed under the Mozilla Public License, v. 2.0. A copy of the license is at
https://mozilla.org/MPL/2.0/. The list is used unmodified; its source is at
https://github.com/publicsuffix/list.

---

## Fluent Emoji

https://github.com/microsoft/fluentui-emoji. The images in
`App/Assets.xcassets/Fluent` are used under the MIT License:

```
MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
```
