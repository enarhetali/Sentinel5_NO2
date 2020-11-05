setwd("D:/Utilisateur/Documents/Documents/Cours/AMSE M2 S4/COVID19/BdF/")
datas_path="../Sentinel5_NO2/datas_sentinel5/archives/"

#Parameter:
remove_Q1=FALSE
encadrement=TRUE
min_loop=8
max_loop=200

library("stringr")
library("tidyr")
library("dplyr")
library("ggplot2")
library("reshape2")
library("olsrr")
library("zoo")

ls=list.files(datas_path)
df=read.csv("encadrement/raw_berlin.csv")[,-c(1)]
city="Berlin"

#Initializing dataframe
df_summary=data.frame(Date=as.Date(c(as.Date("2020-01-09"):as.Date("2020-06-30"))))
df_summary=t(df_summary)
colnames(df_summary)=df_summary[1,]
df_summary=as.data.frame(df_summary)[-c(1),]
df_summary=df_summary[,names(df_summary) != "2020-02-29"] #Fix 29 feb

df_city_mean=apply(df[df$cc_ville==city,c("latitude","longitude")],2,mean)
#Loop optimisation
df["coef"]=df$NO2*df$counter
df=df[df$coef > 0,]

#Optimisation box function #MINIMUM FOR X=5
for(x in c(max_loop:min_loop)){
  for(j in c(max_loop:min_loop)){
    bound_x=0.002000*0.5*x #Latitude
    bound_j=0.002000*j
    
    df_out=df[between(df$latitude, df_city_mean[1]-bound_x, df_city_mean[1]+bound_x) & between(df$longitude, df_city_mean[2]-bound_j, df_city_mean[2]+bound_j),]
    
    df_agg=df_out %>% group_by(Date) %>% summarise(coef = sum(coef), counter=sum(counter))
    df_agg["NO2"]=df_agg$coef/df_agg$counter
    df_agg$Date=as.Date(df_agg$Date)
  
    if(remove_Q1){
      Q1=as.numeric(quantile(df_agg$counter)[2])
      df_agg=df_agg[df_agg$counter >= Q1,]
    }
    
    #Fix date if 2018-12-20 is not included
    if(sum(df_agg$Date <= "2018-12-20") == 0){
      df_agg=rbind(data.frame(Date=as.Date("2018-12-20"), coef=df_agg[1,]$coef, counter=df_agg[1,]$counter, NO2=df_agg[1,]$NO2), df_agg)
    }
    if(sum(df_agg$Date >= "2020-06-30") == 0){
      df_agg=rbind(data.frame(Date=as.Date("2020-06-30"), coef=df_agg[1,]$coef, counter=df_agg[nrow(df_agg),]$counter, NO2=df_agg[nrow(df_agg),]$NO2), df_agg)
    }
    
    #Fixing empty dates
    df_plot=data.frame(Date=seq(min(df_agg$Date), by = "day", length.out = max(df_agg$Date)-min(df_agg$Date)+1))
    df_plot=merge(df_plot, df_agg, by="Date", all.x=T)
    df_plot=df_plot[,-c(2,3)]
    df_plot$NO2=na.approx(df_plot$NO2)
    
    #Rolling average
    df_plot["roll_avg"]=rollmean(df_plot$NO2, 21, align="right", na.pad = TRUE)
    df_plot=df_plot[,-2]
    
    #Compare yearly
    df_2019=df_plot[df_plot$Date >= "2019-01-09" & df_plot$Date <= "2019-06-30",]
    df_2020=df_plot[df_plot$Date >= "2020-01-09" & df_plot$Date != "2020-02-29" & df_plot$Date <= "2020-06-30",]
    
    if(nrow(df_2019) > nrow(df_2020)){
      df_2019=df_2019[substr(df_2019$Date, 6,11) <= substr(max(df_2020$Date),6,11),]
    } else if(nrow(df_2019) < nrow(df_2020)){
      df_2020=df_2020[substr(df_2020$Date, 6,11) <= substr(max(df_2019$Date),6,11),]
    }
    
    #Check in length=df_summary
    
    df_2020["roll_avg_2019"]=df_2019$roll_avg
    df_2020["roll_diff_year"]=((df_2020$roll_avg-df_2019$roll_avg)/df_2019$roll_avg)*100
    
    #df_2020["variable"]=paste0("roll_diff_year_",x,"_",j)
    
    rownames(df_2020)=df_2020$Date
    df_summary=rbind(df_summary,t(df_2020["roll_diff_year"]))
    
    rownames(df_summary)[nrow(df_summary)]=paste0("roll_diff_year_",x,"_",j)
    
    print(paste0(x,"_",j))
  }
}

df_summary=as.data.frame(t(df_summary))
df_summary["Date"]=as.Date(rownames(df_summary))

df_summary[city]=df_WAQI$roll_diff_year

d <- melt(df_summary, id.vars="Date")


#Check correlation
df_cor=df_summary[!is.na(df_summary[,city]),]
df_cor=cor(df_cor[,city],df_cor[,!(names(df_cor) %in% c(city,"Date"))])

#Plot results
x_plot=sapply(strsplit(colnames(df_cor), "year_"), "[[", 2)
df_cor=data.frame(x_plot=as.numeric(sapply(strsplit(x_plot, "_"), "[[", 1)), y_plot=as.numeric(sapply(strsplit(x_plot, "_"), "[[", 2)), val=as.vector(df_cor))


ggplot(df_cor, aes(x=x_plot, y=y_plot, fill=val))+
  geom_tile() +
  ggtitle(paste0("Correlation plot - ",city," - Remove_q1: ",remove_Q1)) +
  xlab("long bounding coefficient") + ylab("lat bounding coefficient") + guides(fill=guide_legend(title="Correlation"))

#Best correlation
print(paste0("Best correlated radius is: 0.002000 * ",df_cor[which.max(df_cor$val),"x_plot"],"_",df_cor[which.max(df_cor$val),"y_plot"]))
print(paste0("Correlation: ", round(max(df_cor$val), 2)))

d_best=d[d$variable %in% c(paste0("roll_diff_year_",df_cor[which.max(df_cor$val),"x_plot"],"_",df_cor[which.max(df_cor$val),"y_plot"]), city),]
ggplot(d_best, aes(Date, value, col=variable)) + 
  geom_line() + 
  ggtitle(paste0("NO2 Daily evolution - ",city," - Best Fitting - Remove_Q1: ",remove_Q1)) +
  labs(caption=paste0("Correlation: ",round(max(df_cor$val), 2)))



