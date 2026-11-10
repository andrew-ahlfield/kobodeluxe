# Install-time script: copy the third party DLLs that an executable needs
# (directly or through other DLLs) from KOBO_DLL_DIR into KOBO_DEST.
#
# CMake's own file(GET_RUNTIME_DEPENDENCIES) lowercases PE import names,
# which fails to find e.g. SDL.dll on a case-sensitive file system when
# cross-compiling, so this walks the import tables with objdump instead.
#
# Inputs: KOBO_EXE, KOBO_DLL_DIR, KOBO_DEST, KOBO_OBJDUMP

file(GLOB available RELATIVE "${KOBO_DLL_DIR}" "${KOBO_DLL_DIR}/*.dll")
set(lower_available "")
foreach(f ${available})
	string(TOLOWER "${f}" lf)
	list(APPEND lower_available "${lf}")
endforeach()

set(queue "${KOBO_EXE}")
set(found "")
while(queue)
	list(POP_FRONT queue current)
	execute_process(COMMAND "${KOBO_OBJDUMP}" -p "${current}"
		OUTPUT_VARIABLE dump RESULT_VARIABLE res)
	if(NOT res EQUAL 0)
		message(FATAL_ERROR "objdump failed on ${current}")
	endif()
	string(REGEX MATCHALL "DLL Name: [^\n]+" imports "${dump}")
	foreach(line ${imports})
		string(REGEX REPLACE "DLL Name: *" "" name "${line}")
		string(STRIP "${name}" name)
		string(TOLOWER "${name}" lname)
		list(FIND lower_available "${lname}" idx)
		# Not in the dependency dir: a Windows system DLL
		if(idx EQUAL -1)
			continue()
		endif()
		list(GET available ${idx} real)
		list(FIND found "${real}" seen)
		if(seen EQUAL -1)
			list(APPEND found "${real}")
			list(APPEND queue "${KOBO_DLL_DIR}/${real}")
		endif()
	endforeach()
endwhile()

foreach(f ${found})
	file(INSTALL "${KOBO_DLL_DIR}/${f}" DESTINATION "${KOBO_DEST}")
endforeach()
