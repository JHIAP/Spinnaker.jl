# Spinnaker.jl: wrapper for FLIR/Point Grey Spinnaker SDK
# Copyright (C) 2019 Samuel Powell

module Spinnaker

using FixedPointNumbers

using Libdl
import Base: unsafe_convert, show, length, getindex, size, convert, range, showerror

export System, Camera, CameraList, SpinError

const libSpinnaker_C = Ref{String}("")
const libSpinVideo_C = Ref{String}("")

const MAX_BUFFER_LEN = Csize_t(1023)

# include API wrapper
include("wrapper/CEnum.jl")
using .CEnum

include("wrapper/spin_common.jl")

struct SpinError <: Exception
  val::spinError
end
showerror(io::IO, ex::SpinError) = print(io, "Spinnaker SDK error: ", ex.val)

function checkerror(err::spinError)
  if err != spinError(0)
    throw(SpinError(err))
  end
  return nothing
end

include("wrapper/spin_api.jl")

# export everything spin*
foreach(names(@__MODULE__, all=true)) do s
  if startswith(string(s), "spin")
    @eval export $s
  end
end

# Include interface
include("SpinImage.jl")
include("CameraImage.jl")
include("System.jl")
include("Camera.jl")
include("CameraList.jl")
include("NodeMap.jl")
include("Nodes.jl")

# Create a System object at runtime
function __init__()
  @static if Sys.iswindows()
    paths = [joinpath(ENV["ProgramFiles"], "FLIR Systems", "Spinnaker", "bin64", "vs2015")]
    libspinnaker = "SpinnakerC_v140.dll"
    libspinvideo = "SpinVideoC_v140.dll"
  elseif Sys.islinux()
    paths = ["/usr/lib" "/opt/spinnaker/lib"]
    libspinnaker = "libSpinnaker_C.so"
    libspinvideo = "libSpinVideo_C.so"
  elseif Sys.isapple()
    paths = ["/usr/local/lib"]
    libspinnaker = "libSpinnaker_C.dylib"
    libspinvideo = "libSpinVideo_C.dylib"
  else
    @error "Spinnaker SDK only supported on Linux, Windows and MacOS platforms"
    return
  end
  libSpinnaker_C_path = ""
  libSpinVideo_C_path = ""
  for path in paths
    libSpinnaker_C_path = joinpath(path, libspinnaker)
    libSpinVideo_C_path = joinpath(path, libspinvideo)
    if isfile(libSpinnaker_C_path) && isfile(libSpinVideo_C_path)
      libSpinnaker_C[] = libSpinnaker_C_path
      libSpinVideo_C[] = libSpinVideo_C_path
    end
  end

  if libSpinnaker_C[] == "" || libSpinVideo_C[] == ""
    @error "Spinnaker SDK cannot be found. This package can be loaded, but will not be functional."
    return
  end
  try
    libSpinnaker_C_handle = dlopen(libSpinnaker_C[])
    !Sys.iswindows() && (libSpinVideo_C_handle = dlopen(libSpinVideo_C[]))
  catch ex
    bt = catch_backtrace()
    @error "Spinnaker SDK cannot be dlopen-ed"
    showerror(stderr, ex, bt)
  end
  try
    global spinsys = System()
  catch ex
    bt = catch_backtrace()
    @error "Spinnaker SDK loaded but Spinnaker.jl failed to initialize"
    showerror(stderr, ex, bt)
  end
end

end # module
