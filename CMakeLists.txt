# Version 2.8 req since it includes the find cuda module
cmake_minimum_required(VERSION 2.8)

project(gpuip)

# Local cmake find modules can be found in the cmake folder
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Common variables for compling the library
set(SOURCE src/gpuip)
set(LIBRARIES)

if (NOT WIN32)
  add_definitions(-Wall)
  add_definitions(-fPIC)
endif()

# Build with OpenCL
option(OpenCL "OpenCL" ON)
if(OpenCL)
  message(STATUS "Generating build with OpenCL...")
  add_definitions(-D_GPUIP_OPENCL)
  find_package(OpenCL REQUIRED)
  include_directories(${OPENCL_INCLUDE_DIRS})
  message(${OPENCL_LIBRARIES})
  set(LIBRARIES ${LIBRARIES} ${OPENCL_LIBRARIES})
  set(SOURCE ${SOURCE} src/opencl)  
else(OpenCL)
  message(STATUS "OpenCL disabled .")
endif(OpenCL)

# Build with CUDA
option(CUDA "CUDA" ON)
if(CUDA)
  message(STATUS "Generating build with CUDA...")
  add_definitions(-D_GPUIP_CUDA)
  find_package(CUDA REQUIRED)
  find_package(CUDADriver REQUIRED)
  include_directories(${CUDA_INCLUDE_DIRS})

  set(LIBRARIES ${LIBRARIES} ${CUDA_LIBRARIES} ${CUDA_DRIVER_LIBRARY})
  set(SOURCE ${SOURCE} src/cuda)  
else(CUDA)
  message(STATUS "CUDA disabled .")
endif(CUDA)

# Build with GLSL (needs OpenGL)
option(GLSL "GLSL" ON)
if(GLSL)
  message(STATUS "Generating build with GLSL...")
  add_definitions(-D_GPUIP_GLSL)
  find_package(OpenGL REQUIRED)   
  
  # Easier to set these manually in windows
  if (WIN32)
	set(GLEW_INCLUDE_DIRS $ENV{GLEW_INCLUDE_DIR})
	set(GLEW_LIBRARY $ENV{GLEW_LIBRARY_DIR}/glew32.lib)
  else (WIN32)
	find_package(GLEW REQUIRED)
  endif(WIN32)
  find_package(GLFW REQUIRED)
  message(${GLFW_LIBRARIES} )
  include_directories(${OPENGL_INCLUDE_DIRS} 
                      ${GLEW_INCLUDE_DIRS} 
                      ${GLFW_INCLUDE_DIRS})  
  set(SOURCE ${SOURCE} src/glsl) 
  set(LIBRARIES ${LIBRARIES} ${OPENGL_LIBRARIES} 
	${GLFW_LIBRARIES} ${GLEW_LIBRARY})
else(GLSL)
  message(STATUS "GLSL disabled .")
endif(GLSL)

# Build the gpuip library
add_library(gpuip_static ${SOURCE})
add_library(gpuip SHARED ${SOURCE})
target_link_libraries(gpuip_static ${LIBRARIES})
target_link_libraries(gpuip ${LIBRARIES})
install(TARGETS gpuip DESTINATION lib)

# Build python bindings (using boost python)
option(PYTHON "PYTHON" ON)
if(PYTHON)
  message(STATUS "Generating build with python bindings...")
  add_definitions(-D_GPUIP_PYTHON_BINDINGS)
  find_package(Boost REQUIRED COMPONENTS python)
  find_package(BoostNumpy REQUIRED)
  find_package(PythonLibs REQUIRED)
  include_directories(${PYTHON_INCLUDE_DIR} ${Boost_INCLUDE_DIRS} ${Boost_NUMPY_INCLUDE_DIRS})

  add_library(pygpuip SHARED src/python.cpp )
  target_link_libraries(pygpuip gpuip_static ${PYTHON_LIBRARIES} 
	${Boost_PYTHON_LIBRARY} ${Boost_NUMPY_LIBRARY})
  
  # Rename python shared lib from libpyGpuip.{so,lib} to pyGpuip.{so,pyd}
  set_target_properties( pygpuip PROPERTIES PREFIX "")
  if (WIN32)
	set_target_properties( pygpuip PROPERTIES SUFFIX ".pyd")
  else (WIN32)
	set_target_properties( pygpuip PROPERTIES SUFFIX ".so")
  endif(WIN32)
  
  # Install python bindings in the python site-packages
  execute_process(COMMAND 
	python -c "from distutils.sysconfig import get_python_lib; print get_python_lib()" 
	OUTPUT_VARIABLE PYTHON_SITE_PACKAGES OUTPUT_STRIP_TRAILING_WHITESPACE)
  install(TARGETS pygpuip DESTINATION ${PYTHON_SITE_PACKAGES})

  add_subdirectory(python)

else(PYTHON)
  message(STATUS "Python bindings disabled.")
endif(PYTHON)

# Enable unit testing
enable_testing()

# Add C++ test
add_executable(test_cpp test/test)
target_link_libraries(test_cpp gpuip_static)
add_test(NAME test_cpp COMMAND test_cpp)

# Add python test
if (PYTHON)
  find_package(PythonInterp REQUIRED)
  configure_file(test/test.py test.py COPYONLY)
  add_test(NAME test_py COMMAND ${PYTHON_EXECUTABLE} test.py)
endif(PYTHON)