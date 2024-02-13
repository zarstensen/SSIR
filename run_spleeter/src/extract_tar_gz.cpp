#include "extract_tar_gz.hpp"

#include <archive.h>
#include <archive_entry.h>

#define LIBARCH_CHECK(r, a, f) \
	r = (f); \
	if (r != ARCHIVE_OK) return { r, std::string(archive_error_string(a)) };

std::pair<int, std::string> extractTarGz(std::filesystem::path arch, std::filesystem::path dest)
{
	int r = ARCHIVE_OK;

	// create archive reader and setup for .tar.gz
	archive* a = archive_read_new();

	archive_read_support_format_tar(a);
	archive_read_support_filter_gzip(a);

	// create archive writer
	archive* ext = archive_write_disk_new();

	archive_write_disk_set_options(ext, ARCHIVE_EXTRACT_TIME);
	archive_write_disk_set_standard_lookup(ext);

	// open passed archive file
	LIBARCH_CHECK(r, a, archive_read_open_filename(a, arch.generic_string().c_str(), 10240));

	// loop over entries in the archive file
	archive_entry* entry = nullptr;

	while (true)
	{
		int r = archive_read_next_header(a, &entry);

		if (r == ARCHIVE_EOF)
			break;

		LIBARCH_CHECK(r, a, r);

		// change entry destination to point inside the passed destination path
		std::filesystem::path entry_path = archive_entry_pathname(entry);

		std::filesystem::path output_path = dest / entry_path;
		
		archive_entry_set_pathname(entry, output_path.generic_string().c_str());

		// write entry to disk
		LIBARCH_CHECK(r, ext, archive_write_header(ext, entry));

		if (archive_entry_size(entry) > 0)
		{
			const void* buff;
			size_t size;
			int64_t offset;

			while (true)
			{
				r = archive_read_data_block(a, &buff, &size, &offset);

				if (r == ARCHIVE_EOF)
					break;

				LIBARCH_CHECK(r, a, r);

				LIBARCH_CHECK(r, ext, archive_write_data_block(ext, buff, size, offset));

			}
		}

		LIBARCH_CHECK(r, ext, archive_write_finish_entry(ext));
	}

	LIBARCH_CHECK(r, ext, archive_write_close(ext));
	LIBARCH_CHECK(r, ext, archive_write_free(ext));

	LIBARCH_CHECK(r, a, archive_read_close(a));
	LIBARCH_CHECK(r, a, archive_read_free(a));

	return { ARCHIVE_OK, "" };
}