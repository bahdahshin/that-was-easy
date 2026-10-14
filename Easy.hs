{-# LANGUAGE ForeignFunctionInterface #-}

-- A reconstruction of Easy.exe for 64-bit Windows, using only base and Win32
-- system DLLs. This is reconstructed behavior, not recovered original source.
-- Build: ghc -O2 -Wall -threaded Easy.hs -o Easy_haskell.exe -luser32 -lkernel32 -optl-mwindows
module Main (main) where

import Control.Concurrent (runInBoundThread)
import Control.Exception (bracket)
import Control.Monad (void)
import Data.Char (ord)
import Data.Word (Word16, Word32)
import Foreign.C.Types (CInt (..))
import Foreign.Marshal.Alloc (allocaBytesAligned)
import Foreign.Marshal.Array (pokeArray, withArray)
import Foreign.Ptr
  ( FunPtr, IntPtr (..), Ptr, WordPtr (..), castPtr, freeHaskellFunPtr, nullPtr )

type HWND = Ptr ()
type DialogProc = HWND -> Word32 -> WordPtr -> IntPtr -> IO IntPtr

-- Windows x64 has one native calling convention, so ccall is appropriate.
-- The modal APIs must be safe FFI calls: they can call back into Haskell.
foreign import ccall safe "DialogBoxIndirectParamW"
  dialogBoxIndirectParamW
    :: Ptr () -> Ptr () -> HWND -> FunPtr DialogProc -> IntPtr -> IO IntPtr

foreign import ccall safe "MessageBoxW"
  messageBoxW :: HWND -> Ptr Word16 -> Ptr Word16 -> Word32 -> IO CInt

foreign import ccall safe "EndDialog"
  endDialog :: HWND -> IntPtr -> IO CInt

foreign import ccall unsafe "ExitProcess"
  exitProcess :: Word32 -> IO ()

foreign import ccall "wrapper"
  wrapDialogProc :: DialogProc -> IO (FunPtr DialogProc)

-- All recovered strings are ASCII; each character is one UTF-16 code unit.
-- This helper is only for these literals, not arbitrary Unicode input.
wideLiteral :: String -> [Word16]
wideLiteral text = map (fromIntegral . ord) text ++ [0]

-- Original DLGTEMPLATE at RVA 0x2000, expressed as little-endian WORDs.
-- DWORD fields have their low WORD first. Windows x64 is little-endian.
-- The first control begins at byte 52, which is DWORD-aligned.
dialogTemplate :: [Word16]
dialogTemplate = concat
  [ [0x00c0, 0x80c8]          -- style = 0x80c800c0
  , [0x0000, 0x0000]          -- extended style
  , [0x0001]                  -- one control
  , [0x0000, 0x0000, 0x00b4, 0x005a] -- x, y, width=180, height=90
  , [0x0000, 0x0000]          -- no menu; default dialog class
  , wideLiteral "Easy"
  , [0x000c]                  -- font size: 12 points
  , wideLiteral "Segoe UI"
  , [0x0001, 0x5001]          -- button style = 0x50010001
  , [0x0000, 0x0000]          -- button extended style
  , [0x002d, 0x001c, 0x005a, 0x001e] -- x=45, y=28, width=90, height=30
  , [0x0001]                  -- IDOK
  , [0xffff, 0x0080]          -- predefined BUTTON class
  , wideLiteral "Easy"
  , [0x0000]                  -- no control creation data
  ]

-- Original callback at RVA 0x1080.
easyDialogProc :: DialogProc
easyDialogProc dialog message wparam _lparam =
  case message of
    0x0110 -> pure 1          -- WM_INITDIALOG: allow default focus handling
    0x0111                   -- WM_COMMAND
      -- cmp r8d, 1 checks all low 32 bits, including notification code.
      | (fromIntegral wparam :: Word32) == 1 -> do
          withArray (wideLiteral "That was easy!") $ \text ->
            withArray (wideLiteral "Easy") $ \caption ->
              void (messageBoxW dialog text caption 0) -- MB_OK
          pure 1
      | otherwise -> pure 0
    0x0010 -> do             -- WM_CLOSE
      void (endDialog dialog 0)
      pure 1
    _ -> pure 0              -- let the dialog manager handle other messages

-- Original entry logic at RVA 0x1000. Keep the callback and template alive
-- for the entire modal call, and keep all GUI calls on one OS thread.
main :: IO ()
main = runInBoundThread $ do
  bracket (wrapDialogProc easyDialogProc) freeHaskellFunPtr $ \callback ->
    allocaBytesAligned (2 * length dialogTemplate) 4 $ \template -> do
      pokeArray (castPtr template :: Ptr Word16) dialogTemplate
      void (dialogBoxIndirectParamW nullPtr template nullPtr callback 0)
  exitProcess 0
