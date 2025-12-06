# Install script for directory: /root/DADI_OverlayBD_demo/overlaybd/src/tools

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "0")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit"
         RPATH "")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/opt/overlaybd/bin/overlaybd-commit")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/opt/overlaybd/bin" TYPE EXECUTABLE FILES "/root/DADI_OverlayBD_demo/overlaybd/build/output/overlaybd-commit")
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit"
         OLD_RPATH "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src/build/libext2fs/lib:"
         NEW_RPATH "")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-commit")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create"
         RPATH "/opt/overlaybd/lib")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/opt/overlaybd/bin/overlaybd-create")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/opt/overlaybd/bin" TYPE EXECUTABLE FILES "/root/DADI_OverlayBD_demo/overlaybd/build/output/overlaybd-create")
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create"
         OLD_RPATH "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src/build/libext2fs/lib:"
         NEW_RPATH "/opt/overlaybd/lib")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-create")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile"
         RPATH "")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/opt/overlaybd/bin/overlaybd-zfile")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/opt/overlaybd/bin" TYPE EXECUTABLE FILES "/root/DADI_OverlayBD_demo/overlaybd/build/output/overlaybd-zfile")
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile"
         OLD_RPATH "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src/build/libext2fs/lib:"
         NEW_RPATH "")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-zfile")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply"
         RPATH "/opt/overlaybd/lib")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/opt/overlaybd/bin/overlaybd-apply")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/opt/overlaybd/bin" TYPE EXECUTABLE FILES "/root/DADI_OverlayBD_demo/overlaybd/build/output/overlaybd-apply")
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply"
         OLD_RPATH "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src/build/libext2fs/lib:"
         NEW_RPATH "/opt/overlaybd/lib")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-apply")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge"
         RPATH "")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/opt/overlaybd/bin/overlaybd-merge")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/opt/overlaybd/bin" TYPE EXECUTABLE FILES "/root/DADI_OverlayBD_demo/overlaybd/build/output/overlaybd-merge")
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge"
         OLD_RPATH "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src/build/libext2fs/lib:"
         NEW_RPATH "")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/opt/overlaybd/bin/overlaybd-merge")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply"
         RPATH "/opt/overlaybd/lib")
  endif()
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/opt/overlaybd/bin/turboOCI-apply")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/opt/overlaybd/bin" TYPE EXECUTABLE FILES "/root/DADI_OverlayBD_demo/overlaybd/build/output/turboOCI-apply")
  if(EXISTS "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply"
         OLD_RPATH "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src/build/libext2fs/lib:"
         NEW_RPATH "/opt/overlaybd/lib")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}/opt/overlaybd/bin/turboOCI-apply")
    endif()
  endif()
endif()

