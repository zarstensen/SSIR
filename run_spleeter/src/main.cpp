#include "extract_tar_gz.hpp"

#include <archive.h>
#include <archive_entry.h>

#include <filesystem>
#include <format>
#include <fstream>

#include <cassert>
#include <iostream>

int main(int argc, const char** argv)
{

	if (!std::filesystem::exists("demucs_env"))
	{
		std::pair<int, std::string> r = extractTarGz("demucs_env.tar.gz", "demucs_env");

		if (r.first != ARCHIVE_OK)
		{
			std::cout << "OH NO:\t" << r.first << '\t' << r.second << std::endl;
			return -1;
		}
		
	}


	system(std::format("\"demucs_env\\scripts\\demucs\" {} ").c_str());


	assert(argc >= 2);

	std::string_view mode = argv[1];

	if (mode == "begin")
	{
		assert(argc == 8);

		std::string_view audio_file = argv[2];
		std::string_view model = argv[3];
		std::string_view device = argv[4];

		std::string_view conda_env_path = argv[5];
		std::string_view conda_env_arch = argv[6];
		std::string res_file = argv[7];

		std::ofstream res_stream(res_file);

		if (!std::filesystem::exists(conda_env_path))
		{
			auto r = extractTarGz(conda_env_path, conda_env_arch);
			
			if (r.first != ARCHIVE_OK)
			{
				res_stream << r.first << '\n' << r.second;
				res_stream.close();
				return -1;
			}
		}

		// run demucs

		int res = system(std::format("\"demucs_env\\scripts\\demucs\" \"{}\" -n {} -d {}",
			audio_file,
			model,
			device)
			.c_str());

		res_stream << res;
		res_stream.close();
	}

	if (mode == "check")
	{
		assert(argc == 3);

		std::string res_file = argv[2];

		if (std::filesystem::exists(res_file))
		{
			std::ifstream res_stream(res_file);

			std::string line;

			std::getline(res_stream, line);

			return std::stoi(line);
		}
		else
			return -1;
	}

}
