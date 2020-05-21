
Sentinel5_NO2
==============================

Downloading, cleaning and aggregation of NO2 (Nitrogen Dioxide) datas from the European satellite Sentinel5. This work is being carried out as part of the AMSECovid19 project.

Project Organization
------------

    ├── LICENSE
    ├── README.md          <- The top-level README for developers using this project.
    │
    ├── datas_sentinel5    <- You have to look here if you are only interested in downloading the data.
    │   ├─ archives            <- File in which the files are recorded and definitively processed
    │   ├─ cleaned             <- Folder where cleaned, non-aggregated records are temporarily stored.
    │   ├─ csv                 <- Data file extracted from the ONDA DIAS API to obtain the links to
    │   │                         download the files.
    │   └─ tracking_files.csv  <- Automatically generated file, allows you to record the days processed,
    │                             with the number of files downloaded. This makes it possible to detect
    │                             the presence of new files for a day that has already been downloaded.
    │
    ├── notebooks          <- Notebooks folders
    │   ├── confidential
    │   │    └──secrets.py        <- Secret script where ID and password are saved to connect to ONDA DIAS
    │   │                            with following elements: user="<your_username"
    │   │                            password = "<your_password>"
    │   ├── analysis.ipynb        <- Give a small analysis of our datas
    │   ├── country_code.py       <- Got all ISO-2 country codes for analysis
    │   └── main.py               <- Main script to run. Download and clean the datas from ESA.
    │
    └── requirements.txt   <- The requirements file for reproducing the analysis environment, e.g.
                              generated with `pip freeze > requirements.txt`

--------
