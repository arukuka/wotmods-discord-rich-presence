cmake_minimum_required(VERSION 3.15)

project(wotmods_discord_rich_precense_package NONE)

if(NOT PYTHON27_EXECUTABLE)
  message(FATAL_ERROR "\"PYTHON27_EXECUTABLE\" must be specified")
endif()

macro(add_python_target TARGET)
  foreach(file ${ARGN})
    set(out ${CMAKE_CURRENT_BINARY_DIR}/${file}c)
    list(APPEND out_files ${out})
    add_custom_command(OUTPUT ${out}
        COMMAND ${PYTHON27_EXECUTABLE} ${PROJECT_SOURCE_DIR}/compile.py "${PROJECT_SOURCE_DIR}/${file}" "${out}")
  endforeach()

  add_custom_target(${TARGET} ALL DEPENDS ${out_files})
endmacro()

macro(configure_files)
  foreach(file ${ARGN})
    string(REGEX REPLACE "(.+)\.in" "\\1" applied "${file}")
    set(out ${CMAKE_CURRENT_BINARY_DIR}/${applied})
    list(APPEND out_files ${out})
    configure_file(${PROJECT_SOURCE_DIR}/${file} ${out} @ONLY)
  endforeach()
endmacro()

file(GLOB_RECURSE PYTHON_SRC RELATIVE ${PROJECT_SOURCE_DIR} ${PROJECT_SOURCE_DIR}/res/*.py)

add_python_target(python_package ${PYTHON_SRC})

file(GLOB_RECURSE META_FILES RELATIVE ${PROJECT_SOURCE_DIR} ${PROJECT_SOURCE_DIR}/*.in)

configure_files(${META_FILES})

install(
  DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/res/ DESTINATION res
  FILES_MATCHING
    PATTERN "*.pyc"
    PATTERN "*.xml"
    PATTERN "*.json"
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/meta.xml DESTINATION ./)
