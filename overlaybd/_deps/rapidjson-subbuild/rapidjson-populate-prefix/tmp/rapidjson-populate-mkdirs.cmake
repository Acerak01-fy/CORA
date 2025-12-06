# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-src"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-build"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix/tmp"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix/src/rapidjson-populate-stamp"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix/src"
  "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix/src/rapidjson-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix/src/rapidjson-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/root/DADI_OverlayBD_demo/overlaybd/_deps/rapidjson-subbuild/rapidjson-populate-prefix/src/rapidjson-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
