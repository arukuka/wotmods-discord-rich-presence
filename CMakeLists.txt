cmake_minimum_required(VERSION 3.15)

project(wotmods_discord_rich_precense_package NONE)

macro(add_python_target TARGET)
  foreach(file ${ARGN})
    set(out ${CMAKE_CURRENT_BINARY_DIR}/${file}c)
    list(APPEND out_files ${out})
    add_custom_command(OUTPUT ${out}
        COMMAND python ${PROJECT_SOURCE_DIR}/compile.py "${PROJECT_SOURCE_DIR}/${file}" "${out}")
  endforeach()

  add_custom_target(${TARGET} ALL DEPENDS ${out_files})
endmacro()

file(GLOB_RECURSE PYTHON_SRC RELATIVE ${PROJECT_SOURCE_DIR} ${PROJECT_SOURCE_DIR}/res/*.py)

add_python_target(python_package ${PYTHON_SRC})

install(DIRECTORY res/ DESTINATION res/ FILES_MATCHING PATTERN "*.pyc")
