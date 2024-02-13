#pragma once

#include <filesystem>
#include <utility>
#include <string>

std::pair<int, std::string> extractTarGz(std::filesystem::path arch, std::filesystem::path dest);
