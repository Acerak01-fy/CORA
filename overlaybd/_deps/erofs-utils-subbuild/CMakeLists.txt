# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.26.5)

# We name the project and the target for the ExternalProject_Add() call
# to something that will highlight to the user what we are working on if
# something goes wrong and an error message is produced.

project(erofs-utils-populate NONE)


# Pass through things we've already detected in the main project to avoid
# paying the cost of redetecting them again in ExternalProject_Add()
set(GIT_EXECUTABLE [==[/usr/bin/git]==])
set(GIT_VERSION_STRING [==[2.43.7]==])
set_property(GLOBAL PROPERTY _CMAKE_FindGit_GIT_EXECUTABLE_VERSION
  [==[/usr/bin/git;2.43.7]==]
)


include(ExternalProject)
ExternalProject_Add(erofs-utils-populate
                     "UPDATE_DISCONNECTED" "False" "GIT_REPOSITORY" "https://git.kernel.org/pub/scm/linux/kernel/git/xiang/erofs-utils.git" "GIT_TAG" "eec6f7a2755dfccc8f655aa37cf6f26db9164e60"
                    SOURCE_DIR          "/root/DADI_OverlayBD_demo/overlaybd/_deps/erofs-utils-src"
                    BINARY_DIR          "/root/DADI_OverlayBD_demo/overlaybd/_deps/erofs-utils-build"
                    CONFIGURE_COMMAND   ""
                    BUILD_COMMAND       ""
                    INSTALL_COMMAND     ""
                    TEST_COMMAND        ""
                    USES_TERMINAL_DOWNLOAD  YES
                    USES_TERMINAL_UPDATE    YES
                    USES_TERMINAL_PATCH     YES
)


