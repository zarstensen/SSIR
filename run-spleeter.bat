echo off
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

set spleeter_cwd=%1
set spleeter_audio_file=%2
set model_name=%3
set spleeter_env_tar=%4

cd /d %spleeter_cwd%

:: check if spleeter-env has been extracted

IF NOT EXIST spleeter-env/NUL (
	echo "Extracting Virtual Environment On First Run (this may take a while...)"
	mkdir spleeter-env
	tar -xf %spleeter_env_tar% -C spleeter-env
)

call ./spleeter-env/Scripts/activate

echo on

python -m spleeter separate --verbose -o spleeter_out -p spleeter:%model_name:"=% %spleeter_audio_file%
exit /b