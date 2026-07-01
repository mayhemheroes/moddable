/* ASan tuning for xst: OSS-Fuzz used detect_leaks=0 (see mayhem/xst.options); keep quarantine
 * small so the ~40MB instrumented binary can start under constrained hosts. */
const char *__asan_default_options(void) {
    return "detect_leaks=0:quarantine_size_mb=1:allocator_release_to_os_interval_ms=1000:"
           "malloc_context_size=0:max_allocation_size_mb=512";
}
