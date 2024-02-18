echo off

set conda_env=%1
set device=%2
set audio_file=%3
set model_name=%4
set output_path=%5

call "%conda_env%\Scripts\activate"

echo on

demucs %audio_file% -n %model_name:"=% -d %device:"=% --out %output_path%

exit /b