#!/usr/bin/env julia
using ArgParse
using DelimitedFiles
using Shell
Shell.setshell("sh")

s = ArgParseSettings()
@add_arg_table s begin
    "--class", "-c"
        help = "class"
        arg_type = String
        default = "abseiling"
    "--sourcedir", "-s"
        help = "source dir"
        arg_type = String
        default = "/mnt/lustre/share/linziyi/851103c18f12cf27a6004ee1b52d53bf/Kinetics-400_FAIR/train_256"
    "--targetdir", "-t"
        help = "target dir"
        arg_type = String
        default = "/mnt/lustrenew/share/lizz/kinetics400/train_256"
    "--step"
        help = "optical flow step"
        arg_type = Int
        default = 1
    "--bound"
        help = "optical flow bound"
        arg_type = Int
        default = 32
    "--alg", "-a"
        help = "tvl1"
        arg_type = String
        default = "tvl1"
    "--parallel"
        help = "n parallel"
        arg_type = Int
        default = 1
end
args = parse_args(s)

# 0. prepare
SOURCEDIR = joinpath(args["sourcedir"], args["class"])
TARGETDIR = joinpath(args["targetdir"], args["class"])
ALGORITHM = args["alg"]
STEP = args["step"]
BOUND = args["bound"]
PARALLEL = args["parallel"]
DONEDIR = joinpath(TARGETDIR, ".done")
mkpath(DONEDIR)

# 1. find all folders needed to process
ITEMS = [i[1:end - 4] for i in readdir(SOURCEDIR)]
DONES = readdir(DONEDIR)
ITEMS = collect(setdiff(Set(ITEMS), Set(DONES)))
println("$(length(ITEMS)) items to process at $(gethostname())")

asyncmap(ITEMS; ntasks=PARALLEL) do item
    TMPFILE = tempname() * ".txt"
    writedlm(TMPFILE, [joinpath(SOURCEDIR, "$item.mp4")])
    Shell.run("""
./build/extract_nvflow -v="$(TMPFILE)" -o="$(TARGETDIR)" -a=$(ALGORITHM) -s=$(STEP) -b=$(BOUND)
    """)
    rm(TMPFILE, force=true)
end
