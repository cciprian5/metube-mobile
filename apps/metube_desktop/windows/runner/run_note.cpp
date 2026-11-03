#include "run_note.h"

#include <shlobj.h>
#include <windows.h>

#include <cstdio>
#include <cwchar>
#include <string>

namespace {

// Both names are read by lib/platform/run_note.dart, in the folder the app
// keeps its log in. Filled in advance: a crashing process should not be
// asked to allocate.
wchar_t g_crash_path[MAX_PATH * 2] = {};
wchar_t g_open_path[MAX_PATH * 2] = {};

LONG WINAPI NoteCrash(EXCEPTION_POINTERS* info) {
  const EXCEPTION_RECORD* record = info->ExceptionRecord;
  HMODULE module = nullptr;
  wchar_t path[MAX_PATH] = L"unknown";
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         static_cast<LPCWSTR>(record->ExceptionAddress),
                         &module)) {
    GetModuleFileNameW(module, path, MAX_PATH);
  }
  // The file's name alone: the folder holds the user's name, and the log
  // can be shared.
  const wchar_t* slash = wcsrchr(path, L'\\');
  const wchar_t* name = slash ? slash + 1 : path;
  const unsigned long long offset =
      module ? static_cast<const char*>(record->ExceptionAddress) -
                   reinterpret_cast<const char*>(module)
             : 0;
  char line[512];
  const int length =
      snprintf(line, sizeof(line), "code 0x%08lX in %ls at +0x%llX",
               record->ExceptionCode, name, offset);
  HANDLE file = CreateFileW(g_crash_path, GENERIC_WRITE, 0, nullptr,
                            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    DWORD written = 0;
    if (length > 0) WriteFile(file, line, length, &written, nullptr);
    CloseHandle(file);
  }
  // Windows still reports the crash and keeps its dump.
  return EXCEPTION_CONTINUE_SEARCH;
}

}  // namespace

void InstallRunNote() {
  PWSTR local = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local))) {
    return;
  }
  const std::wstring folder = std::wstring(local) + L"\\MeTube Ember\\logs\\";
  CoTaskMemFree(local);
  const std::wstring crash = folder + L"last_crash.txt";
  const std::wstring open = folder + L"ember.running";
  if (wcsncpy_s(g_crash_path, crash.c_str(), _TRUNCATE) != 0 ||
      wcsncpy_s(g_open_path, open.c_str(), _TRUNCATE) != 0) {
    return;
  }
  SetUnhandledExceptionFilter(NoteCrash);
}

void NoteWindowsEnding() {
  if (g_open_path[0] != L'\0') DeleteFileW(g_open_path);
}
