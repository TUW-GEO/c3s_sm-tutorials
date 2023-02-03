conda env export --no-builds | grep -v "prefix" > environment.yml
black -l 79 *.ipynb
jupyter nbconvert --to html T1_DataAccess_Anomalies --output T1_DataAccess_Anomalies
