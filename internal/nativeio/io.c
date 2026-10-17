/* Native file I/O only. No sample conversion or DSP is implemented in C. */
#include "moonbit.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <windows.h>
#include <io.h>
#else
#include <unistd.h>
#endif

static FILE *open_path(const char *path, int writing) {
#ifdef _WIN32
  int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
  if (count <= 0) return NULL;
  wchar_t *wide = (wchar_t *)malloc((size_t)count * sizeof(wchar_t));
  if (!wide) return NULL;
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, count)) {
    free(wide); return NULL;
  }
  FILE *file = _wfopen(wide, writing ? L"wbx" : L"rb");
  free(wide);
  return file;
#else
  return fopen(path, writing ? "wbx" : "rb");
#endif
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonsrc_read_file(moonbit_bytes_t path) {
  FILE *file = open_path((const char *)path, 0);
  if (!file) return moonbit_make_bytes(0, 0);
  int64_t length = -1;
#ifdef _WIN32
  struct _stat64 status;
  if (_fstat64(_fileno(file), &status) == 0 && (status.st_mode & _S_IFMT) == _S_IFREG)
    length = status.st_size;
#else
  struct stat status;
  if (fstat(fileno(file), &status) == 0 && S_ISREG(status.st_mode)) length = status.st_size;
#endif
  if (length <= 0 || length > 33554476) {
    fclose(file); return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)length, 0);
  size_t count = fread(bytes, 1, (size_t)length, file);
  int extra = fgetc(file);
  int read_error = ferror(file);
  int close_error = fclose(file);
  if (count != (size_t)length || extra != EOF || read_error || close_error) {
    moonbit_decref(bytes); return moonbit_make_bytes(0, 0);
  }
  return bytes;
}

MOONBIT_FFI_EXPORT int moonsrc_write_new_file(moonbit_bytes_t path, moonbit_bytes_t bytes) {
  FILE *file = open_path((const char *)path, 1);
  if (!file) return -1;
  size_t length = (size_t)Moonbit_array_length(bytes);
  size_t written = fwrite(bytes, 1, length, file);
  int close_error = fclose(file);
  return written == length && close_error == 0 ? 0 : -1;
}

MOONBIT_FFI_EXPORT void moonsrc_exit(int code) { exit(code); }
