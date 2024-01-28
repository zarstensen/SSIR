echo off
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

set spleeter_cwd=%1
set spleeter_audio_file=%2

cd /d %spleeter_cwd%

:: check if spleeter-env has been extracted

IF NOT EXIST spleeter-env/NUL (
	echo "Extracting Virtual Environment On First Run (this may take a while...)"
	mkdir spleeter-env
	tar -xf spleeter-env.zip -C spleeter-env
)

call ./spleeter-env/Scripts/activate.bat

echo on

spleeter separate --verbose -o spleeter_out -p spleeter:4stems %spleeter_audio_file%
exit /b