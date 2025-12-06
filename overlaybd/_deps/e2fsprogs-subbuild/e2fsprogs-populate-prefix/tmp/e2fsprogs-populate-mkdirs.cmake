# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-src"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-build"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix/tmp"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix/src/e2fsprogs-populate-stamp"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix/src"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix/src/e2fsprogs-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix/src/e2fsprogs-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/root/DADI_OverlayBD_demo/overlaybd/_deps/e2fsprogs-subbuild/e2fsprogs-populate-prefix/src/e2fsprogs-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
