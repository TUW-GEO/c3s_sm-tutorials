conda env export --no-builds | grep -v "prefix" > environment.yml
jupyter nbconvert --to rst T1_DataAccess\&Anomalies --output T1_DataAccess\&Anomalies

