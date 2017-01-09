include (ExternalProject)

set_property (DIRECTORY PROPERTY EP_PREFIX dependencies)

set (NETGEN_DEPENDENCIES)
set (LAPACK_DEPENDENCIES)
set (NETGEN_CMAKE_ARGS)

set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" "${PROJECT_SOURCE_DIR}/cmake_modules")

macro(set_vars VAR_OUT)
  foreach(varname ${ARGN})
    if(NOT "${${varname}}" STREQUAL "")
      string(REPLACE ";" "$<SEMICOLON>" varvalue "${${varname}}" )
      list(APPEND ${VAR_OUT} -D${varname}=${varvalue})
    endif()
  endforeach()
endmacro()
#######################################################################
if(WIN32)
  if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
    string(REGEX REPLACE "/W[0-4]" "/W0" CMAKE_CXX_FLAGS_NEW ${CMAKE_CXX_FLAGS})
    set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS_NEW} CACHE STRING "compile flags" FORCE)
    string(REGEX REPLACE "/W[0-4]" "/W0" CMAKE_CXX_FLAGS_NEW ${CMAKE_CXX_FLAGS_RELEASE})
    set(CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_NEW} CACHE STRING "compile flags" FORCE)

    string(REGEX REPLACE "/W[0-4]" "/W0" CMAKE_SHARED_LINKER_FLAGS_NEW ${CMAKE_SHARED_LINKER_FLAGS})
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS_NEW} /IGNORE:4217,4049" CACHE STRING "compile flags" FORCE)
    string(REGEX REPLACE "/W[0-4]" "/W0" CMAKE_EXE_LINKER_FLAGS_NEW ${CMAKE_EXE_LINKER_FLAGS})
    set(CMAKE_EXE_LINKER_FLAGS"${CMAKE_EXE_LINKER_FLAGS_NEW}/IGNORE:4217,4049" CACHE STRING "compile flags" FORCE)

    set_vars(NETGEN_CMAKE_ARGS CMAKE_SHARED_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS_RELEASE CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_RELEASE)
  endif(NOT CMAKE_CXX_COMPILER_ID STREQUAL "Intel")

  if(${CMAKE_SIZEOF_VOID_P} MATCHES 4)
    # 32 bit
    set(EXT_LIBS_DOWNLOAD_URL_WIN "http://www.asc.tuwien.ac.at/~mhochsteger/ngsuite/ext_libs32.zip" CACHE STRING INTERNAL)
    set(OCC_DOWNLOAD_URL_WIN "http://www.asc.tuwien.ac.at/~mhochsteger/ngsuite/occ32.zip" CACHE STRING INTERNAL)
  else(${CMAKE_SIZEOF_VOID_P} MATCHES 4)
    # 64 bit
    set(EXT_LIBS_DOWNLOAD_URL_WIN "http://www.asc.tuwien.ac.at/~mhochsteger/ngsuite/ext_libs64.zip" CACHE STRING INTERNAL)
    set(OCC_DOWNLOAD_URL_WIN "http://www.asc.tuwien.ac.at/~mhochsteger/ngsuite/occ64.zip" CACHE STRING INTERNAL)
  endif(${CMAKE_SIZEOF_VOID_P} MATCHES 4)
endif(WIN32)

#######################################################################
# find netgen
set(INSTALL_DIR /opt/netgen CACHE PATH "Install path")
if(APPLE)
  set(CMAKE_INSTALL_PREFIX "${INSTALL_DIR}/Netgen.app/Contents/Resources" CACHE INTERNAL "Prefix prepended to install directories" FORCE)
else(APPLE)
  set(CMAKE_INSTALL_PREFIX "${INSTALL_DIR}" CACHE INTERNAL "Prefix prepended to install directories" FORCE)
endif(APPLE)

if(NOT WIN32)
    find_package(ZLIB REQUIRED)
    set_vars(NETGEN_CMAKE_ARGS ZLIB_INCLUDE_DIRS ZLIB_LIBRARIES)
endif(NOT WIN32)

#######################################################################
if (USE_PYTHON)
    find_path(PYBIND_INCLUDE_DIR pybind11/pybind11.h ${CMAKE_CURRENT_SOURCE_DIR}/external_dependencies/pybind11/include)
    if( NOT PYBIND_INCLUDE_DIR )
      execute_process(COMMAND git submodule update --init --recursive WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
        find_path(PYBIND_INCLUDE_DIR pybind11/pybind11.h ${CMAKE_CURRENT_SOURCE_DIR}/external_dependencies/pybind11/include)
    endif( NOT PYBIND_INCLUDE_DIR )
    if( PYBIND_INCLUDE_DIR )
        message("-- Found Pybind11: ${PYBIND_INCLUDE_DIR}")
    else( PYBIND_INCLUDE_DIR )
        message(FATAL_ERROR "Could NOT find pybind11!")
    endif( PYBIND_INCLUDE_DIR )
    find_package(PythonInterp 3 REQUIRED)
    find_package(PythonLibs 3 REQUIRED)

    set(PYTHON_LIBS "${PYTHON_LIBRARIES}")
    execute_process(COMMAND ${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib(1,0,''))" OUTPUT_VARIABLE PYTHON_PACKAGES_INSTALL_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)
    file(TO_CMAKE_PATH ${PYTHON_PACKAGES_INSTALL_DIR} PYTHON_PACKAGES_INSTALL_DIR)
    set_vars(NETGEN_CMAKE_ARGS PYTHON_LIBS PYTHON_LIBRARY PYTHON_PACKAGES_INSTALL_DIR PYTHON_INCLUDE_DIR PYBIND_INCLUDE_DIR PYTHON_LIBRARIES PYTHON_EXECUTABLE PYTHON_VERSION)
endif (USE_PYTHON)

#######################################################################

if(USE_OCC AND WIN32)
    ExternalProject_Add(win_download_occ
      PREFIX ${CMAKE_CURRENT_BINARY_DIR}/tcl
      URL ${OCC_DOWNLOAD_URL_WIN}
      UPDATE_COMMAND "" # Disable update
      BUILD_IN_SOURCE 1
      CONFIGURE_COMMAND ""
      BUILD_COMMAND ""
      INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory . ${INSTALL_DIR}
      LOG_DOWNLOAD 1
      )
    list(APPEND NETGEN_DEPENDENCIES win_download_occ)
endif(USE_OCC AND WIN32)

#######################################################################

if(USE_GUI)
  include(cmake_modules/ExternalProject_TCLTK.cmake)
endif(USE_GUI)

#######################################################################
# propagate cmake variables to Netgen subproject
set_vars( NETGEN_CMAKE_ARGS
  USE_GUI
  USE_PYTHON
  USE_MPI
  USE_VT
  USE_VTUNE
  USE_NUMA
  USE_CCACHE
  USE_NATIVE_ARCH
  USE_OCC
  INSTALL_DIR
  INSTALL_DEPENDENCIES
  INTEL_MIC
  )

ExternalProject_Add (netgen
  DEPENDS ${NETGEN_DEPENDENCIES}
  SOURCE_DIR ${PROJECT_SOURCE_DIR}
  CMAKE_ARGS -DUSE_SUPERBUILD=OFF ${NETGEN_CMAKE_ARGS} -DCMAKE_PREFIX_PATH=${INSTALL_DIR}
  INSTALL_COMMAND ""
  BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/netgen
  BUILD_COMMAND ${CMAKE_COMMAND} --build ${CMAKE_CURRENT_BINARY_DIR}/netgen --config ${CMAKE_BUILD_TYPE}
  STEP_TARGETS build
)

install(CODE "execute_process(COMMAND cmake --build . --target install --config ${CMAKE_BUILD_TYPE} WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/netgen)")

add_custom_target(test_netgen
  ${CMAKE_COMMAND} --build ${CMAKE_CURRENT_BINARY_DIR}/netgen
                   --target test
                   --config ${CMAKE_BUILD_TYPE}
                   )
