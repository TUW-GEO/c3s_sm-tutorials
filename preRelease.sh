#conda env export --no-builds | grep -v "prefix" > environment.yml
black -l 99 *.ipynb
jupyter nbconvert --to html T1_DataAccess_Anomalies.ipynb --output T1_DataAccess_Anomalies
