conda_env="$1"
device="$2"
audio_file="$3"
model_name="$4"
output_path="$5"

source "$conda_env/bin/activate"

demucs "$audio_file" -n "${model_name//\"/}" -d "${device//\"/}" --out "$output_path"