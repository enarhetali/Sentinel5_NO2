import pandas as pd
import numpy as np
import os
from datetime import datetime
import time

import requests
import json
import zipfile

from netCDF4 import Dataset
import reverse_geocoder as rg

#This is where you put logs for https://www.onda-dias.eu/cms/
#Example of the contents of the file:
# user="my_username"
# password="my_secret_password"
from confidential import secrets

#CONFIG
path_drive="../" #Directory pointing to /datas_sentinel5/
path='../datas_sentinel5/' #Directory pointing AFTER /datas_sentinel5/

# Pour téléchargez les données, veuillez vous enregistrer sur le site ONDA: https://www.onda-dias.eu/cms/
# CF. previous lines to understand how to configure the secrets file.
user = secrets.user #Email
password = secrets.password #Password

# Download settings
Param_API=True #True: Query to the ONDA API + recording in a CSV | False: Playback of recorded CSVs without asking the API
Param_Download=True #True: Download the files from ONDA DIAS API
Param_Tracking=True #True: write in tracking_files.csv. It may be useful to disable this option when you want to fix a bug that appears during data download.


#Useless function
def f_poly(x):
    poly=[[[elem.replace("((","")]] for elem in x[14:-3].split(")),")]
    poly=[[j.split(" ") for j in poly[i][0][0].split(",")] for i in range(0,len(poly))]
    return [poly]

#Function to write logs to the console with a nice timer
def timer():
    return '['+datetime.now().strftime("%d/%m/%Y %H:%M:%S")+']'

#Distances between two coordinates
def distance(origin, destination):
    lat1, lon1 = origin
    lat2, lon2 = destination
    radius = 6373 # km

    dlat = np.radians(lat2-lat1)
    dlon = np.radians(lon2-lon1)
    a = np.sin(dlat/2) * np.sin(dlat/2) + np.cos(np.radians(lat1)) \
        * np.cos(np.radians(lat2)) * np.sin(dlon/2) * np.sin(dlon/2)
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    d = radius * c

    return d


#File existence check in datas_sentinel5
ls=[path_drive+"datas_sentinel5", path_drive+"datas_sentinel5/cleaned", path_drive+"datas_sentinel5/archives", path_drive+"datas_sentinel5/csv"]
for elem in ls:
    if(os.path.isdir(elem)==0):
        try:
            os.mkdir(elem)
        except OSError:
            print ("Creation of the directory failed")

#Maximum number of lines returned by the API. Maximum is 1000.
top=300

#Updated files available for download
files=[i for i in os.listdir(path_drive+"datas_sentinel5/csv") if os.path.isfile(os.path.join(path_drive+"datas_sentinel5/csv",i)) and 'infos' in i]
#If there is one file in our datas_sentinel5/csv/ folder:
if len(files)!=0:
    #Read more recent file
    ls=[os.path.getmtime(path_drive+"datas_sentinel5/csv/"+i) for i in os.listdir(path_drive+"datas_sentinel5/csv") if os.path.isfile(os.path.join(path_drive+"datas_sentinel5/csv",i)) and 'infos' in i]
    infos=pd.read_csv(path_drive+"datas_sentinel5/csv/"+files[ls.index(max(ls))], index_col=0)
    infos.creationDate=pd.to_datetime(infos.creationDate)
    #Store max date in a variable
    max_date=infos.creationDate.max()
    
    #If Timedelta > 1 day & Param_API is ON : We start API
    if (pd.Timestamp.today(tz="UTC")-max_date >= pd.Timedelta('1 days')) & Param_API:
        url="https://catalogue.onda-dias.eu/dias-catalogue/Products?$search=%22name:S5P_OFFL_L2__NO2*%22&$top="+str(top)+"&$orderby=creationDate%20desc&$skip=0&$format=json"

        response=requests.get(url)
        response=json.loads(response.content.decode('utf-8'))
        #Cleaning
        keys=["id","name","creationDate","beginPosition","size","downloadable","offline","footprint"]
        infos=[[elem.get(key) for key in keys] for elem in response["value"]]
        infos=pd.DataFrame(infos,columns=keys)
        infos.creationDate=pd.to_datetime(infos.creationDate)
        infos.beginPosition=pd.to_datetime(infos.beginPosition)
        #Remove when creationDate < max_date
        infos=infos[infos.creationDate >= max_date]
        #Save as CSV
        infos.to_csv(path_drive+"datas_sentinel5/csv/infos_"+infos.creationDate.dt.strftime('%Y_%m_%d_%H_%M')[len(infos.creationDate)-1]+"_to_"+infos.creationDate.dt.strftime('%Y_%m_%d_%H_%M')[0]+".csv")
        del(infos)

##MAIN GOAL: See which days can be fully download
#Timer to observe the program execution time
global_start = time.time()
all_files=pd.DataFrame()
#List all files in datas_sentinel5/csv/ folder. It's important to do it again because some files may have been added by the API in the previous condition
ls=[i for i in os.listdir(path_drive+"datas_sentinel5/csv") if os.path.isfile(os.path.join(path_drive+"datas_sentinel5/csv",i)) and 'infos' in i]
#Reading all files and cleaning
for elem in ls:
    df=pd.read_csv(path_drive+"datas_sentinel5/csv/"+elem, index_col=0)
    df.creationDate=pd.to_datetime(df.creationDate)
    df.beginPosition=pd.to_datetime(df.beginPosition)
    all_files=pd.concat([all_files, df], axis=0)
      
all_files=all_files.reset_index(drop=True)

#Group by day
calendar=all_files.groupby(all_files.beginPosition.dt.floor("D")).sum()

#Add absent dates from the last date to today
while pd.Timestamp.today(tz="UTC").floor("D")-calendar.asfreq('D').index.max()>pd.Timedelta('1 days'):
    calendar_add=pd.DataFrame([[calendar.index.max()+pd.Timedelta('1 days'),0,0,0]], columns=['beginPosition','size','downloadable','offline'])
    calendar_add=calendar_add.set_index("beginPosition")
    calendar=pd.concat([calendar,calendar_add])

#Adds absent dates and replaces with 0
calendar=calendar.asfreq('D').fillna(0)

#Add day of week
calendar["dayofweek"]=calendar.index.dayofweek.values

#As categorical: we will download a day ONLY if the global coverage is enough.
calendar["categorical"]=0 #No files availables this day
calendar.loc[calendar.downloadable > 0,"categorical"]=1 #At least one file is available
calendar.loc[calendar.downloadable >= 12,"categorical"]=2 #Green light

#We're looking at which days have already been downloaded
if os.path.isfile(path_drive+"datas_sentinel5/tracking_files.csv"):
    tracking_files=pd.read_csv(path_drive+"datas_sentinel5/tracking_files.csv", index_col=0)
    tracking_files.date=pd.to_datetime(tracking_files.date)
    tracking_files=tracking_files.drop_duplicates()
else:
    tracking_files=pd.DataFrame([[pd.Timestamp.today(tz="UTC").floor("D")-pd.Timedelta('31 days'),0]], columns=["date","number"])

#Group by day
tracking_files=tracking_files.groupby(tracking_files.date.dt.floor("D")).sum()

#Add absent dates from the last date to today
tracking_files_add=pd.DataFrame([[calendar.index.min(),0],[calendar.index.max(),0]], columns=["date","number"]).set_index("date")
tracking_files=pd.concat([tracking_files_add,tracking_files])
tracking_files=tracking_files.sort_index()
tracking_files=tracking_files.asfreq('D').fillna(0)

#Combine to calendar
calendar["number"]=tracking_files["number"]
calendar["new_available"]=calendar.downloadable-calendar.number

#Here it is the difference between the number of files available for one day and the number of files already downloaded. In other words, we observe the new files to download
calendar["categorical"]=0 #No new files available
calendar.loc[calendar.new_available > 0,"categorical"]=1 #Be carefull: a new file have been added on this day
calendar.loc[calendar.new_available >= 12,"categorical"]=2 #A new day can be downloaded

#Create link to download files
all_files["urls"]="https://catalogue.onda-dias.eu/dias-catalogue/Products("+all_files.id+")/$value"
all_files=all_files.drop_duplicates()
all_files=all_files.sort_values("beginPosition", ascending=False)

##MAIN LOOP: One loop = one day we can download.
for elem_to_dl in calendar[calendar.categorical==2].index:
    #Floor to day
    infos=all_files[all_files.beginPosition.dt.floor("D")==elem_to_dl]
    infos=infos.drop_duplicates('name')
    tot_files=infos.shape[0]
    #Remove when size is too small or too big (Extremes files lead to errors)
    infos=infos[(infos["size"]>150000000) & (infos["size"]<1000000000)] #No more than 1 Go
    infos=infos.reset_index(drop=True)

    i=list(range(0,infos.shape[0]))
    
    #Downloading the files
    if Param_Download==True:
        to_pop=[]
        #This loop will appear often. It's to do the treatments sequentially.
        for k in i:
            ls=[elem[:-3] for elem in os.listdir(path)]
            #Check if file doesn't already exist
            #Start downloading
            if(infos.loc[k,"name"][:-4] in ls)==False:
                print('\033[0m'+timer()+'[INFO] Beginning download file '+ infos.name[k])
                r = requests.get(infos.loc[k,"urls"], auth=(user, password))
                print(timer()+'[INFO] Code '+str(r.status_code))
                #Catch error
                if r.status_code != 200:
                    #New try every minutes
                    while r.status_code != 200:
                        print('\033[1;31;48m'+timer()+'[ERROR] Error '+str(r.status_code)+'. Retry in 1 minute')
                        time.sleep(60)
                        r = requests.get(infos.loc[k,"urls"], auth=(user, password))
                
                with open(path+infos.loc[k,"name"], 'wb') as f:
                    f.write(r.content)
                print('\033[0m'+timer()+'[INFO] Unzip file')
                #Unzip file in a try because errors might occur
                try:
                    with zipfile.ZipFile(path+infos.loc[k,"name"], 'r') as zip_ref:
                        zip_ref.extractall(path)
                    print(timer()+'[INFO] Delete zipfile')
                    os.remove(path+infos.loc[k,"name"])
                    print(timer()+'[SUCCESS] The file '+infos.name[k]+' has been downloaded and unzipped.')
                except Exception:
                    print('\033[1;31;48m'+timer()+'[WARNING] File '+infos.name[k]+' is not a zip file \033[0m')
                    os.remove(path+infos.loc[k,"name"])
                    infos=infos[infos.name != infos.name[k]]
                    to_pop.append(k)
        
        #Remove files who got an error from the loops 
        for k in to_pop:
            i.pop(i.index(k))

    #Start reading datas in dictionnary. Check NETCDF4 for more information
    rootgrp=dict()
    for k in i:
        rootgrp[k]=Dataset(path+infos.loc[k,"name"][:-3]+"nc", "r", format="NETCDF4")
    
    to_pop=[]
    #Check if PRODUCT groups and nitrogendioxide_tropospheric_column variable are in the file. If not, we expulse the file.
    for k in i:
        if ("PRODUCT" not in rootgrp[k].groups.keys()):
            rootgrp[k].close()
            os.remove(path+infos.name[k][:-3]+"nc")
            print('\033[1;31;48m'+timer()+'[WARNING] PRODUCT '+str(k)+' not in groups. File '+infos.name[k]+' have been removed. \033[0m')
            infos=infos[infos.name != infos.name[k]]
            to_pop.append(k)
        elif ("nitrogendioxide_tropospheric_column" not in rootgrp[k].groups["PRODUCT"].variables.keys()):
            rootgrp[k].close()
            os.remove(path+infos.name[k][:-3]+"nc")
            print('\033[1;31;48m'+timer()+'[WARNING] nitrogendioxide_tropospheric_column '+str(k)+' not in variables. File '+infos.name[k]+' have been removed. \033[0m')
            infos=infos[infos.name != infos.name[k]]
            to_pop.append(k)
      
    #Remove files who got an error from the loops 
    for k in to_pop:
            i.pop(i.index(k))
            
    #Cleaning and rework datas to a Dataframe
    df_sat=dict()
    for k in i:
        lon_x=rootgrp[k].groups["PRODUCT"].variables["longitude"][0].data.flatten()
        lat_x=rootgrp[k].groups["PRODUCT"].variables["latitude"][0].data.flatten()
        z_value=rootgrp[k].groups["PRODUCT"].variables["nitrogendioxide_tropospheric_column"][0].data.flatten()
        qa_value=rootgrp[k].groups["PRODUCT"].variables["qa_value"][0].data.flatten()
        df_sat[k]=pd.DataFrame({'longitude': lon_x, 'latitude': lat_x, 'NO2':z_value,'quality':qa_value})

    for k in i:
        df_sat[k]["date"]=np.full((450,rootgrp[k].groups["PRODUCT"].variables["time_utc"].shape[1]), rootgrp[k].groups["PRODUCT"].variables["time_utc"][0]).flatten("F")

    #Get locations infos from latitude and longitude. check reverse_geocoder package for more informations
    coordinates=dict()
    results=dict()
    start_time = time.time()
    for k in i:
        coordinates[k] =list(zip(df_sat[k]["latitude"], df_sat[k]["longitude"]))
        results[k] =rg.search(coordinates[k])
      
    print(timer()+'[INFO] Linked with countries in %s seconds ---' % (time.time() - start_time))

    #Merge columns created
    for k in i:
        results[k]=pd.DataFrame.from_dict(results[k])
        results[k]=results[k].rename(columns={"lat":"cc_lat","lon":"cc_lon","name":"cc_ville","admin1":"cc_region","admin2":"cc_departement","cc":"cc_pays"})

    for k in i:
        df_sat[k]=pd.concat([df_sat[k], results[k]], axis=1)
        #Convert to float
        df_sat[k].cc_lon=df_sat[k].cc_lon.astype(float)
        df_sat[k].cc_lat=df_sat[k].cc_lat.astype(float)

    for k in i:
        #Compute distances
        df_sat[k]["dist"]=distance([df_sat[k].latitude, df_sat[k].longitude], [df_sat[k].cc_lat, df_sat[k].cc_lon])
        #Keep country infos only if dist <= 30
        df_sat[k].loc[df_sat[k].dist > 30, ["cc_ville","cc_region", "cc_region", "cc_departement", "cc_pays"]]=float("NaN")
        #Remove columns generated
        df_sat[k]=df_sat[k].drop(['cc_lat', 'cc_lon', "dist"], axis=1)
    
    #Cleaning is over: we save the day in the csv tracking file
    if Param_Tracking==True:
        #Save the number of files downloaded in the the tracking file
        if os.path.isfile(path_drive+"datas_sentinel5/tracking_files.csv"):
            temp=pd.read_csv(path_drive+"datas_sentinel5/tracking_files.csv", index_col=0)
            temp_add=pd.DataFrame([[infos.beginPosition.max().floor("D"),tot_files]], columns=["date","number"])
            temp=pd.concat([temp, temp_add])
            temp.to_csv(path_drive+"datas_sentinel5/tracking_files.csv")
            del(temp, temp_add)
        else:
            pd.DataFrame([[infos.beginPosition.max().floor("D"),infos.shape[0]]], columns=["date","number"]).to_csv(path_drive+"datas_sentinel5/tracking_files.csv")
            
    #Temporarily saves non-aggregated files in the /cleaned folder
    df_plot=pd.DataFrame()
    for k in i:
        df_sat[k].to_csv(path+"cleaned/"+infos.name[k][:-3]+"csv")
        rootgrp[k].close()
        os.remove(path+infos.name[k][:-3]+"nc")

    #Free some RAM space:
    del(df_sat, coordinates, lat_x, lon_x, rootgrp, results, start_time)

    #Read files in /cleaned starting with "S5P_OFFL_L2__NO2"
    files_list=[i for i in os.listdir(path+"cleaned") if os.path.isfile(os.path.join(path+"cleaned/",i)) and 'S5P_OFFL_L2__NO2' in i]
    i=list(range(0,len(files_list)))

    #Row bind for plot
    df_plot=pd.DataFrame()
    
    #Read files and concat in one dataframe
    for k in range(0,len(files_list)):
        df_sat=pd.read_csv(path+"cleaned/"+files_list[k], index_col=0)
        df_sat.date=pd.to_datetime(df_sat.date)
        df_plot=pd.concat([df_plot, df_sat])
        del(df_sat)
        #Restrictions quality. Datas with quality < 0.75 are falses/wrongs. See ESA documentation for more informations.
        df_plot=df_plot[df_plot["quality"]>=0.75]

    #It is mandatory to replace NaN by "Undefined" to not loose datas
    df_plot=df_plot.fillna("Undefined")
    #Add Counter too. This will be usefull when we will aggregate datas to avoid loosing information
    df_plot["counter"]=1

    #The date is recorded in several separate columns to be able to test if the aggregations have been carried out correctly. 
    #For example, if we observe that the standard deviation is greater than several hours, we can suspect that the satellite has made several passes over the same city.
    df_plot["hour_mean"]=df_plot.date.dt.hour
    df_plot["hour_std"]=df_plot.date.dt.hour
    df_plot["day_std"]=df_plot.date.dt.day
    df_plot["day_mean"]=df_plot.date.dt.day
    df_plot["dayofweek_std"]=df_plot.date.dt.dayofweek
    df_plot["dayofweek_mean"]=df_plot.date.dt.dayofweek
    df_plot["week"]=df_plot.date.dt.week
    df_plot["month"]=df_plot.date.dt.month
    df_plot["year"]=df_plot.date.dt.year

    #Aggregation
    df_plot=df_plot.groupby(["year","month","week","cc_pays","cc_departement","cc_region","cc_ville"], as_index=False).agg({'longitude':'mean', 'latitude':'mean', 'NO2':'mean', 'quality':'mean', 'hour_mean':'mean', 'hour_std':'std', 'dayofweek_mean':'mean', 'dayofweek_std':'std', 'day_mean':'mean', 'day_std':'std','counter':'sum'})

    #Save final aggregated file as CSV in /archives folder
    filename="archived_"+str(df_plot.year.value_counts()[df_plot.year.value_counts()==df_plot.year.value_counts().max()].index[0])+"_"+str(df_plot.month.value_counts()[df_plot.month.value_counts()==df_plot.month.value_counts().max()].index[0])+"_"+str(int(df_plot.day_mean.value_counts()[df_plot.day_mean.value_counts()==df_plot.day_mean.value_counts().max()].index[0]))+".csv"
    df_plot.to_csv(path_drive+"datas_sentinel5/archives/"+filename)

    #Cleaning files in /cleaned folder
    del(df_plot)
    for k in range(0,len(files_list)):
        os.remove(path+"cleaned/"+files_list[k])

    print('\033[1;32;48m'+timer()+'[SUCCESS] The day have been downloaded and cleaned in '+str((time.time() - global_start)/60))