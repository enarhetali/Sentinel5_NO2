setwd("D:/Utilisateur/Documents/Documents/Cours/AMSE M2 S4/COVID19/BdF/")
datas_path="../Sentinel5_NO2/datas_sentinel5/archives/"

#Parameter:
remove_Q1=FALSE
encadrement=TRUE

library("stringr")
library("tidyr")
library("dplyr")
library("ggplot2")
library("reshape2")
library("olsrr")
library("zoo")

ls=list.files(datas_path)
df=read.csv("encadrement/raw_paris.csv")[,-c(1)]
city="Paris"

#Check for multiple running
if(exists("df_summary")){
  remove(df_summary)
}

df_city_mean=apply(df[df$cc_ville==city,c("latitude","longitude")],2,mean)

#Optimisation box function #MINIMUM FOR X=5
for(x in c(8:200)){
  bound=0.002000*x

  df_out=df[between(df$latitude, df_city_mean[1]-bound, df_city_mean[1]+bound) & between(df$longitude, df_city_mean[2]-bound, df_city_mean[2]+bound),]
  
  df_out["coef"]=df_out$NO2*df_out$counter
  
  #Remove negative values
  df_out=df_out[df_out$coef > 0,]
  
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
  
  #Fixing empty dates
  df_plot=data.frame(Date=seq(min(df_agg$Date), by = "day", length.out = max(df_agg$Date)-min(df_agg$Date)+1))
  df_plot=merge(df_plot, df_agg, by="Date", all.x=T)
  df_plot=df_plot[,-c(2,3)]
  df_plot$NO2=na.approx(df_plot$NO2)
  
  #Rolling average
  df_plot["roll_avg"]=rollmean(df_plot$NO2, 21, align="right", na.pad = TRUE)
  
  #Compare yearly
  df_2019=df_plot[df_plot$Date >= "2019-01-09" & df_plot$Date <= "2019-06-30",]
  df_2020=df_plot[df_plot$Date >= "2020-01-09" & df_plot$Date != "2020-02-29" & df_plot$Date <= "2020-06-30",]
  
  if(nrow(df_2019) > nrow(df_2020)){
    df_2019=df_2019[substr(df_2019$Date, 6,11) <= substr(max(df_2020$Date),6,11),]
  } else if(nrow(df_2019) < nrow(df_2020)){
    df_2020=df_2020[substr(df_2020$Date, 6,11) <= substr(max(df_2019$Date),6,11),]
  }
  
  df_2020["roll_avg_2019"]=df_2019$roll_avg
  df_2020["roll_diff_year"]=((df_2020$roll_avg-df_2019$roll_avg)/df_2019$roll_avg)*100

  #Create table summary
  if(!exists("df_summary")){
    df_summary=data.frame(Date=as.Date(c(as.Date("2020-01-09"):as.Date("2020-06-30"))))
  }
  
  df_summary=merge(df_summary, df_2020[,c(1,5)], by="Date", all.x=T)
  colnames(df_summary)[ncol(df_summary)]=paste0("roll_diff_year_",x)
}

#Add Grenoble city datas
df_summary=df_summary[df_summary$Date != "2020-02-29",]
df_summary[city]=df_WAQI$roll_diff_year

d <- melt(df_summary, id.vars="Date")
d["Linetype"]="solid"
d["size"]=0.5
d["alpha"]=0.3

d[d$variable==city,"Linetype"]="dashed"
d[d$variable==city,"size"]=1
d[d$variable==city,"alpha"]=1

# Everything on the same plot
ggplot(d, aes(Date,value, col=variable)) + 
  geom_line(linetype=d$Linetype,size=d$size, alpha=d$alpha)+ 
  theme(legend.position = "none")+ 
  ggtitle(paste0("NO2 Daily evolution - ",city," - Bounding optimisation - Remove_q1: ",remove_Q1)) +
  labs(caption="The dashed line corresponds to the source/ground data.")



#Check correlation
df_cor=df_summary[!is.na(df_summary[,ncol(df_summary)]),]
df_cor=cor(df_cor[,ncol(df_cor)],df_cor[,-c(1,ncol(df_cor))])

#Plot results
x_plot=sapply(strsplit(colnames(df_cor), "year_"), "[[", 2)
df_cor=data.frame(x_plot=as.numeric(x_plot), y_plot=as.vector(df_cor))
ggplot(df_cor, aes(x=x_plot, y=y_plot))+
  geom_point() +
  ggtitle(paste0("Correlation plot - ",city," - Remove_q1: ",remove_Q1)) +
  xlab("bounding coefficient") + ylab("correlation")

#Best correlation
print(paste0("Best correlated radius is: 0.002000 * ",df_cor[which.max(df_cor$y_plot),"x_plot"]))
print(paste0("Correlation: ", round(max(df_cor$y_plot), 2)))

d_best=d[d$variable %in% c(paste0("roll_diff_year_",df_cor[which.max(df_cor$y_plot),"x_plot"]), city),]
ggplot(d_best, aes(Date,value, col=variable)) + 
  geom_line() + 
  ggtitle(paste0("NO2 Daily evolution - ",city," - Best Fitting - Remove_Q1: ",remove_Q1)) +
  labs(caption=paste0("Correlation: ",round(max(df_cor$y_plot), 2)))



