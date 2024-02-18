call "./demucs_nvidia_env/Scripts/activate"

conda install pytorch torchvision torchaudio pytorch-cuda=12.1 python ffmpeg -c pytorch -c nvidia -y && pip install demucs
