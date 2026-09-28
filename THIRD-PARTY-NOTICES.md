# Third-party notices

## Wunder.ClickOnceUninstaller

The dialog-free uninstall (`Uninstall-ClickOnceApplication -Method Direct`) is a PowerShell port of the approach and
algorithm of [Wunder.ClickOnceUninstaller](https://github.com/rongchunzhang/Wunder.ClickOnceUninstaller)
(originally developed by 6 Wunderkinder GmbH for Wunderlist), which is available under the MIT license.
The ported parts are `Read-CoClickOnceRegistry`, `Get-CoComponentToRemove`, `Get-CoUninstallPlan` and
`Invoke-CoPlanAction` (from `ClickOnceRegistry`, `Uninstaller`, `RemoveFiles`, `RemoveStartMenuEntry`,
`RemoveRegistryKeys` and `RemoveUninstallEntry`).

```text
MIT License

Copyright (c) 6 Wunderkinder GmbH

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

## SilentClickOnce

The module is inspired by the function of
[SilentClickOnce.exe](https://github.com/PaaaulZ/SilentClickOnce) (PaaaulZ/SilentClickOnce).
No source code of that project is used.
