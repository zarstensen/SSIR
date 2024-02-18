#include <asio.hpp>

#include "extract_tar_gz.hpp"

#include <archive.h>
#include <archive_entry.h>


#include <filesystem>
#include <fmt/format.h>
#include <fstream>
#include <thread>

#include <cassert>
#include <iostream>

using asio::ip::tcp;

constexpr std::string_view DEMUCS_NVIDIA_ENV = "demucs_nvidia_env";
constexpr std::string_view DEMUCS_CPU_ENV = "demucs_cpu_env";
constexpr std::string_view PORT_FILE = "tcp_port.txt";

constexpr int STILL_PROCESSING = 0;
constexpr int DONE = 1;
constexpr int FAIL_UNKNOWN = 2;
constexpr int FAIL_EXTRACT = 3;

void runDemucs(std::string_view audio_file, std::string_view model, std::string_view device, std::string_view conda_env_arch, std::string_view destination_directory, bool& finished, int& ret_val)
{
	std::string env;

	if (device == "cpu")
		env = DEMUCS_CPU_ENV;
	else if (device == "nvidia")
		env = DEMUCS_NVIDIA_ENV;

	if (!std::filesystem::exists(env))
	{
		std::cout << "TRY EXTRACT TAR!\n" << env << '\n' << conda_env_arch << '\n';
		auto r = extractTarGz(conda_env_arch, env);

		if (r.first != ARCHIVE_OK)
		{
			ret_val = FAIL_EXTRACT;
			finished = true;
			return;
		}

		std::cout << "Installing demucs, this may take a while..." << std::endl;

		if (device == "cpu")
			std::system("install-demucs");
		else if (device == "nvidia")
			std::system("install-demucs-nvidia");
	}

	std::string demucs_device;

	if (device == "cpu")
		demucs_device = "cpu";
	else if (device == "nvidia")
		demucs_device = "cuda";

	// run demucs

	int res = system(fmt::format("run-demucs \"{}\" {} \"{}\" {} \"{}\"",
		env,
		demucs_device,
		audio_file,
		model,
		destination_directory)
		.c_str());


	// move splitted files to destination directory.
	// TODO

	finished = true;
	ret_val = DONE;
}

int main(int argc, const char** argv)
{
	assert(argc >= 3);

	std::string_view cwd = argv[1];
	std::string_view mode = argv[2];

	std::filesystem::current_path(cwd);

	if (mode == "begin")
	{
		assert(argc == 8);
		
		bool demucs_finished = false;
		int result = FAIL_UNKNOWN;

		std::thread demucs_thread(runDemucs, argv[3], argv[4], argv[5], argv[6], argv[7], std::ref(demucs_finished), std::ref(result));

		// start tcp server

		asio::io_context io_context;

		auto endpoint = tcp::endpoint(asio::ip::tcp::v4(), 0);
		endpoint.address(asio::ip::make_address("127.0.0.1"));

		tcp::acceptor acceptor(io_context, endpoint);

		{
			// write port to disk
			std::ofstream port_out((std::string)PORT_FILE);

			port_out << acceptor.local_endpoint().port() << std::endl;
		}

		while (!demucs_finished)
		{
			tcp::socket socket(io_context);
			acceptor.accept(socket);

			asio::write(socket, asio::buffer(&STILL_PROCESSING, sizeof(int)));
		}

		demucs_thread.join();
		tcp::socket socket(io_context);
		acceptor.accept(socket);

		asio::write(socket, asio::buffer(&result, sizeof(int)));
	}

	if (mode == "check")
	{
		assert(argc == 4);

		std::string_view port = argv[3];

		asio::io_context io_context;

		tcp::socket socket(io_context);
		tcp::resolver resolver(io_context);

		int ret_val = FAIL_UNKNOWN;
	
		try
		{
			// IMPORTANT: if the correct endpoint is not resolved here as the only endpoint,
			// there will be a significant delay when trying to connect, as it will wait for timeouts on the incorrect endpoints.

			auto endpoint = resolver.resolve(tcp::v4(), "localhost", port);

			asio::connect(socket, endpoint);

			size_t bytes = asio::read(socket, asio::buffer(&ret_val, sizeof(int)));
		} 
		catch(std::exception e) { }

		return ret_val;
	}

}
