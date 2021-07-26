cmake_minimum_required(VERSION 3.15)

project(wotmods_discord_rich_precense_readme NONE)

macro(configure_files)
  foreach(file ${ARGN})
    string(REGEX REPLACE "(.+)\.in" "\\1" applied "${file}")
    message("file: ${file}, applied: ${applied}")
    set(out ${CMAKE_CURRENT_BINARY_DIR}/${applied})
    list(APPEND out_files ${out})
    configure_file(${PROJECT_SOURCE_DIR}/${file} ${out} @ONLY)
  endforeach()
endmacro()

file(GLOB_RECURSE META_FILES RELATIVE ${PROJECT_SOURCE_DIR} ${PROJECT_SOURCE_DIR}/*.in)

configure_files(${META_FILES})

install(
  DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/readme DESTINATION package
  FILES_MATCHING
    PATTERN "*.txt"
)
