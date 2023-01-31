conda activate c3s_sm-tutorials
conda env export --no-builds | grep -v "prefix" > environment.yml
jupyter nbconvert --to notebook ./notebook/*.ipynb --output-dir ./convert 
