#include "dense_flow.h"
#include "opencv2/opencv.hpp"
#include "utils.h"
#include <clue/stringex.hpp>
#include <clue/textio.hpp>

INITIALIZE_EASYLOGGINGPP

using namespace cv::cuda;
using boost::filesystem::create_directories;
using clue::line_stream;
using clue::read_file_content;
using clue::string_view;
using clue::trim;

int main(int argc, char **argv) {
    try {
        const char *keys = {"{ v video        | video.mp4        | filename of video or a list.txt of videos }"
                            "{ o outputDir    | /path/to/outputs | root dir of output }"
                            "{ a algorithm    | nv               | optical flow algorithm (nv/tvl1/farn/brox) }"
                            "{ s step         | 1                | right - left (0 for img, non-0 for flow) }"
                            "{ b bound        | 32               | maximum of optical flow }"
                            "{ w newWidth     | 0                | new width }"
                            "{ h newHeight    | 0                | new height }"
                            "{ sh short       | 0                | short side length }"
                            "{ d deviceId     | 0                | set gpu id }"
                            "{ cf classFolder |                  | outputDir/class/video/flow.jpg }"
                            "{ vv verbose     |                  | verbose }"
                            "{ help           |                  | print help message }"};

        CommandLineParser cmd(argc, argv, keys);
        path video_path(cmd.get<string>("video"));
        path output_dir(cmd.get<string>("outputDir"));
        string algorithm = cmd.get<string>("algorithm");
        int step = cmd.get<int>("step");
        int bound = cmd.get<int>("bound");
        int new_width = cmd.get<int>("newWidth");
        int new_height = cmd.get<int>("newHeight");
        int new_short = cmd.get<int>("short");
        int device_id = cmd.get<int>("deviceId");
        bool has_class = cmd.has("classFolder");
        bool verbose = cmd.has("verbose");

        cmd.about("GPU optical flow extraction.");
        if (cmd.has("help") || !cmd.check()) {
            cmd.printMessage();
            cmd.printErrors();
            return 0;
        }

        Mat::setDefaultAllocator(HostMem::getAllocator(HostMem::AllocType::PAGE_LOCKED));
        Stream stream;

        if (video_path.extension() == ".txt") {
            string text = read_file_content(video_path.c_str());
            line_stream lstr(text);
            for (string_view line : lstr) {
                try {
                    path vidfile(trim(line).to_string());
                    path outdir;
                    if (has_class) {
                        outdir = output_dir / vidfile.parent_path().filename() / vidfile.stem();
                    } else {
                        outdir = output_dir / vidfile.stem();
                    }
                    create_directories(outdir);
                    calcDenseNvFlowVideoGPU(vidfile, outdir, algorithm, step, bound, new_width, new_height, new_short,
                                            device_id, verbose, stream);
                    // mark done
                    path donedir;
                    if (has_class) {
                        donedir = output_dir / ".done" / vidfile.parent_path().filename();
                    } else {
                        donedir = output_dir / ".done";
                    }
                    path donefile = donedir / vidfile.stem();
                    create_directories(donedir);
                    createFile(donefile);
                } catch (const std::exception &ex) {
                    std::cout << trim(line) << " errored: " << ex.what() << std::endl;
                }
            }
        } else {
            calcDenseNvFlowVideoGPU(video_path, output_dir, algorithm, step, bound, new_width, new_height, new_short,
                                    device_id, verbose, stream);
        }

    } catch (const std::exception &ex) {
        std::cout << ex.what() << std::endl;
        return 1;
    }
    return 0;
}
