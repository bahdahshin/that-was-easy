# Easy.exe reconstruction

`easy.c` is a behavior-based C reconstruction from the executable's x64
instructions and embedded dialog template. Original source code, identifiers,
and comments cannot be recovered. The rebuilt executable is not byte-identical;
the compiler adds its own startup code and PE metadata.

## Binary facts

- Original size: 2,048 bytes; Windows GUI PE32+ (AMD64).
- SHA-256: `4CEE84C9E33735E77072FF0380A688FB742E2FC54ACE4012A639133B1B53E5F0`.
- Preferred image base: `0x140000000`; entry point RVA: `0x1000`.
- Imports: `DialogBoxIndirectParamW`, `EndDialog`, `MessageBoxW` from
  `user32.dll`, and `ExitProcess` from `kernel32.dll`.
- Two sections: `.text` and `.data`; no resource directory or symbols.

## Recovered behavior

The entry point opens a modal dialog from the template at RVA `0x2000`, passing
NULL for the instance and owner, the callback at RVA `0x1080`, and zero for the
initialization parameter. After the dialog returns, it calls `ExitProcess(0)`.

The dialog is titled **Easy**, with dimensions 180 by 90 dialog units and a
12-point Segoe UI font. Its style is `0x80c800c0`. It has one default push button,
also titled **Easy**, at (45, 28), sized 90 by 30 dialog units, with ID 1 and
style `0x50010001`.

The callback implements these branches:

| Message | Result |
| --- | --- |
| `WM_INITDIALOG` (`0x110`) | Return TRUE. |
| `WM_COMMAND` (`0x111`), low 32 bits of `wParam` equal to 1 | Show `MessageBoxW(dialog, L"That was easy!", L"Easy", 0)`; return TRUE. |
| `WM_CLOSE` (`0x10`) | Call `EndDialog(dialog, 0)`; return TRUE. |
| Anything else | Return FALSE. |

The original comparison includes the notification code, so the reconstruction
deliberately does not replace it with `LOWORD(wParam) == IDOK`. There is no
explicit `IDCANCEL` branch. The message and caption are stored at RVAs `0x2100`
and `0x2140` respectively.

## Build

From this folder with a MinGW-w64 compiler:

```powershell
gcc -std=c11 -Wall -Wextra -Werror -O2 -mwindows easy.c -o Easy_rebuilt.exe -luser32
```

`Easy.exe` remains the original input; `Easy_rebuilt.exe` is the new output.

## Verification

The reconstruction compiles successfully with the command above, with warnings
treated as errors. A binary comparison confirms that the rebuilt executable
contains the exact original 86-byte dialog template and both message strings.
The original code is recorded in `Easy_disassembly.txt`. Interactive GUI
behavior has not been runtime-tested.

## Haskell reconstruction

`Easy.hs` reconstructs the same entry logic and callback using direct foreign
function imports from the Windows DLLs. It requires 64-bit Windows and a
64-bit Windows GHC installation; no third-party Haskell packages are required.
Build from this folder with:

```powershell
ghc -O2 -Wall -threaded Easy.hs -o Easy_haskell.exe -luser32 -lkernel32 -optl-mwindows
```

The modal API imports use safe FFI calls so Windows can invoke the Haskell
callback. The callback and DWORD-aligned template stay allocated until the
dialog closes, and GUI execution stays on a bound OS thread. The low-32-bit
command comparison and explicit `ExitProcess(0)` match the disassembly.

The Haskell template's 86 bytes were checked against the original executable
and match exactly. GHC 9.6.7 was subsequently installed from the official Windows
binary distribution, verified against its published SHA-256 checksum, under
`%LOCALAPPDATA%\Programs\Haskell\ghc-9.6.7-x86_64-unknown-mingw32`.
Its `bin` directory was added to the user PATH. Compilation and linking of
`Easy_haskell.exe` succeeded with `-Wall -Werror`. The FFI imports explicitly
bring the `IntPtr` and `WordPtr` constructors into scope, as GHC requires.
Interactive GUI behavior has not been runtime-tested.

An already-open PowerShell session can pick up the installed compiler with:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Programs\Haskell\ghc-9.6.7-x86_64-unknown-mingw32\bin"
ghc --version
```
