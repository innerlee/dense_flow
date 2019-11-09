#!/usr/bin/env julia
using ArgParse
using DelimitedFiles
using Glob
using MLDataUtils
using Shell
Shell.setshell("sh")

s = ArgParseSettings()
@add_arg_table s begin
    "--sourcedir", "-s"
        help = "source dir"
        arg_type = String
        default = "/mnt/lustre/lizz/data/Kinetics-400_FAIR/val_256"
    "--targetdir", "-t"
        help = "target dir"
        arg_type = String
        default = "/dev/shm/kinetics-val"
    "--step"
        help = "optical flow step"
        arg_type = Int
        default = 1
    "--bound"
        help = "optical flow bound"
        arg_type = Int
        default = 32
    "--alg", "-a"
        help = "nv | tvl1"
        arg_type = String
        default = "tvl1"
    "--split"
        help = "which split to process"
        arg_type = Int
        default = 1
    "--splits"
        help = "How many splits"
        arg_type = Int
        default = 8
    "--batch"
        help = "how many file each time"
        arg_type = Int
        default = 64
end
args = parse_args(s)

# 0. prepare
SPLIT = args["split"]
SPLITS = args["splits"]
SOURCEDIR = args["sourcedir"]
TARGETDIR = args["targetdir"]
ALGORITHM = args["alg"]
STEP = args["step"]
BOUND = args["bound"]
BATCH = args["batch"]
DONEDIR = joinpath(TARGETDIR, ".done")
mkpath(DONEDIR)

# 1. find all folders needed to process
ITEMS = splitobs(glob("*/*", SOURCEDIR), at=tuple(ones(SPLITS-1)/SPLITS...))[SPLIT]
DONES = glob("*/*", DONEDIR)
DONE_KEYS = Set([joinpath(rsplit(x, "/")[end-1:end]...) for x in DONES])
ITEM_TODO = [joinpath(rsplit(x, "/")[end-1], splitext(basename(x))[1]) ∉ DONE_KEYS for x in ITEMS]
ITEMS = ITEMS[ITEM_TODO]
println("$(length(ITEMS)) items to process at $(gethostname())")

n = ceil(Int, length(ITEMS)/BATCH)
for i in 1:n
    TMPFILE = tempname() * ".txt"
    writedlm(TMPFILE, ITEMS[(i-1) * BATCH + 1 : min(i * BATCH, end)])
    println("$i/$n, ", TMPFILE)
    Shell.run("""
cd /mnt/lustre/lizz/dev/dense_flow
./extract_nvflow -v="$(TMPFILE)" -o="$(TARGETDIR)" -a=$(ALGORITHM) -s=$(STEP) -b=$(BOUND) -cf
    """)
    rm(TMPFILE, force=true)
end
