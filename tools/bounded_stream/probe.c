/* Monotonic timing and OS process memory only; this file does no audio work. */
#include "moonbit.h"
#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
#include <psapi.h>
MOONBIT_FFI_EXPORT double moonsrc_probe_seconds(void) {
  LARGE_INTEGER now, frequency;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&now);
  return (double)now.QuadPart / (double)frequency.QuadPart;
}
MOONBIT_FFI_EXPORT int64_t moonsrc_probe_rss(int peak) {
  PROCESS_MEMORY_COUNTERS counters;
  if (!K32GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters))) return -1;
  return (int64_t)(peak ? counters.PeakWorkingSetSize : counters.WorkingSetSize);
}
#else
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>
#include <stdio.h>
MOONBIT_FFI_EXPORT double moonsrc_probe_seconds(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec + (double)now.tv_nsec / 1000000000.0;
}
MOONBIT_FFI_EXPORT int64_t moonsrc_probe_rss(int peak) {
  if (peak) {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0) return -1;
#ifdef __APPLE__
    return (int64_t)usage.ru_maxrss;
#else
    return (int64_t)usage.ru_maxrss * 1024;
#endif
  }
#ifdef __linux__
  FILE *file = fopen("/proc/self/statm", "r");
  if (!file) return -1;
  unsigned long total = 0, resident = 0;
  int parsed = fscanf(file, "%lu %lu", &total, &resident);
  fclose(file);
  if (parsed != 2) return -1;
  return (int64_t)resident * (int64_t)sysconf(_SC_PAGESIZE);
#else
  return -1;
#endif
}
#endif
