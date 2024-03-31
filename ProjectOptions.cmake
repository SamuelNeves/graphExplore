include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(graphExplore_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(graphExplore_setup_options)
  option(graphExplore_ENABLE_HARDENING "Enable hardening" ON)
  option(graphExplore_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    graphExplore_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    graphExplore_ENABLE_HARDENING
    OFF)

  graphExplore_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR graphExplore_PACKAGING_MAINTAINER_MODE)
    option(graphExplore_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(graphExplore_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(graphExplore_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(graphExplore_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(graphExplore_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(graphExplore_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(graphExplore_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(graphExplore_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(graphExplore_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(graphExplore_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(graphExplore_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(graphExplore_ENABLE_PCH "Enable precompiled headers" OFF)
    option(graphExplore_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(graphExplore_ENABLE_IPO "Enable IPO/LTO" ON)
    option(graphExplore_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(graphExplore_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(graphExplore_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(graphExplore_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(graphExplore_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(graphExplore_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(graphExplore_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(graphExplore_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(graphExplore_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(graphExplore_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(graphExplore_ENABLE_PCH "Enable precompiled headers" OFF)
    option(graphExplore_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      graphExplore_ENABLE_IPO
      graphExplore_WARNINGS_AS_ERRORS
      graphExplore_ENABLE_USER_LINKER
      graphExplore_ENABLE_SANITIZER_ADDRESS
      graphExplore_ENABLE_SANITIZER_LEAK
      graphExplore_ENABLE_SANITIZER_UNDEFINED
      graphExplore_ENABLE_SANITIZER_THREAD
      graphExplore_ENABLE_SANITIZER_MEMORY
      graphExplore_ENABLE_UNITY_BUILD
      graphExplore_ENABLE_CLANG_TIDY
      graphExplore_ENABLE_CPPCHECK
      graphExplore_ENABLE_COVERAGE
      graphExplore_ENABLE_PCH
      graphExplore_ENABLE_CACHE)
  endif()

  graphExplore_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (graphExplore_ENABLE_SANITIZER_ADDRESS OR graphExplore_ENABLE_SANITIZER_THREAD OR graphExplore_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(graphExplore_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(graphExplore_global_options)
  if(graphExplore_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    graphExplore_enable_ipo()
  endif()

  graphExplore_supports_sanitizers()

  if(graphExplore_ENABLE_HARDENING AND graphExplore_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR graphExplore_ENABLE_SANITIZER_UNDEFINED
       OR graphExplore_ENABLE_SANITIZER_ADDRESS
       OR graphExplore_ENABLE_SANITIZER_THREAD
       OR graphExplore_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${graphExplore_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${graphExplore_ENABLE_SANITIZER_UNDEFINED}")
    graphExplore_enable_hardening(graphExplore_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(graphExplore_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(graphExplore_warnings INTERFACE)
  add_library(graphExplore_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  graphExplore_set_project_warnings(
    graphExplore_warnings
    ${graphExplore_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(graphExplore_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    graphExplore_configure_linker(graphExplore_options)
  endif()

  include(cmake/Sanitizers.cmake)
  graphExplore_enable_sanitizers(
    graphExplore_options
    ${graphExplore_ENABLE_SANITIZER_ADDRESS}
    ${graphExplore_ENABLE_SANITIZER_LEAK}
    ${graphExplore_ENABLE_SANITIZER_UNDEFINED}
    ${graphExplore_ENABLE_SANITIZER_THREAD}
    ${graphExplore_ENABLE_SANITIZER_MEMORY})

  set_target_properties(graphExplore_options PROPERTIES UNITY_BUILD ${graphExplore_ENABLE_UNITY_BUILD})

  if(graphExplore_ENABLE_PCH)
    target_precompile_headers(
      graphExplore_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(graphExplore_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    graphExplore_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(graphExplore_ENABLE_CLANG_TIDY)
    graphExplore_enable_clang_tidy(graphExplore_options ${graphExplore_WARNINGS_AS_ERRORS})
  endif()

  if(graphExplore_ENABLE_CPPCHECK)
    graphExplore_enable_cppcheck(${graphExplore_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(graphExplore_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    graphExplore_enable_coverage(graphExplore_options)
  endif()

  if(graphExplore_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(graphExplore_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(graphExplore_ENABLE_HARDENING AND NOT graphExplore_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR graphExplore_ENABLE_SANITIZER_UNDEFINED
       OR graphExplore_ENABLE_SANITIZER_ADDRESS
       OR graphExplore_ENABLE_SANITIZER_THREAD
       OR graphExplore_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    graphExplore_enable_hardening(graphExplore_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
