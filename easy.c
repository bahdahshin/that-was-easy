/* Reconstructed from Easy.exe (x64), not the original source.
 * Build with MinGW-w64:
 *   gcc -std=c11 -Wall -Wextra -O2 -mwindows easy.c -o Easy_rebuilt.exe -luser32
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>

/* The original embeds a standard DLGTEMPLATE at RVA 0x2000.
 * Variable-length fields are written out explicitly; each control starts
 * on a DWORD boundary. Coordinates and sizes are in dialog units.
 */
#pragma pack(push, 2)
typedef struct EasyDialogTemplate {
    DWORD style;
    DWORD extended_style;
    WORD control_count;
    short x, y, width, height;
    WORD menu;
    WORD window_class;
    WCHAR title[5];
    WORD font_size;
    WCHAR font_name[9];

    DWORD button_style;
    DWORD button_extended_style;
    short button_x, button_y, button_width, button_height;
    WORD button_id;
    WORD button_class[2];
    WCHAR button_title[5];
    WORD button_creation_data_size;
} EasyDialogTemplate;
#pragma pack(pop)

_Static_assert(offsetof(EasyDialogTemplate, button_style) == 52,
               "Dialog control must start at original offset 52");
_Static_assert(sizeof(EasyDialogTemplate) == 86,
               "Dialog template must match the original 86 bytes");

/* The union guarantees the DWORD alignment required by the dialog API. */
static const union {
    DWORD alignment;
    EasyDialogTemplate dialog;
} easy_template = { .dialog = {
    .style = WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_SETFONT | DS_MODALFRAME,
    .extended_style = 0,
    .control_count = 1,
    .x = 0, .y = 0, .width = 180, .height = 90,
    .menu = 0,
    .window_class = 0,
    .title = L"Easy",
    .font_size = 12,
    .font_name = L"Segoe UI",
    .button_style = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
    .button_extended_style = 0,
    .button_x = 45, .button_y = 28,
    .button_width = 90, .button_height = 30,
    .button_id = IDOK,
    .button_class = { 0xffff, 0x0080 }, /* Predefined BUTTON class. */
    .button_title = L"Easy",
    .button_creation_data_size = 0
} };

/* Original callback: RVA 0x1080. */
static INT_PTR CALLBACK easy_dialog_proc(HWND dialog, UINT message,
                                         WPARAM wparam, LPARAM lparam)
{
    (void)lparam;

    switch (message) {
    case WM_INITDIALOG:
        return TRUE;

    case WM_COMMAND:
        /* The original compares all 32 low bits (r8d), not just LOWORD.
         * Preserve that behavior, including the notification code check.
         */
        if ((DWORD)wparam == IDOK) {
            MessageBoxW(dialog, L"That was easy!", L"Easy", MB_OK);
            return TRUE;
        }
        return FALSE;

    case WM_CLOSE:
        EndDialog(dialog, 0);
        return TRUE;

    default:
        return FALSE;
    }
}

/* A conventional C entry point wraps the original entry logic at RVA 0x1000. */
int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous_instance,
                   LPSTR command_line, int show_command)
{
    (void)instance;
    (void)previous_instance;
    (void)command_line;
    (void)show_command;

    DialogBoxIndirectParamW(NULL, (LPCDLGTEMPLATE)&easy_template.dialog,
                            NULL, easy_dialog_proc, 0);
    ExitProcess(0);
}
