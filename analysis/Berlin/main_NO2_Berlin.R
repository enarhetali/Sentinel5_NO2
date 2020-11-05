setwd("D:/Utilisateur/Documents/Documents/Cours/AMSE M2 S4/COVID19/BdF/Berlin/")

library("stringr")
library("tidyr")
library("dplyr")
library("ggplot2")
library("reshape2")
library("olsrr")
library("zoo")



#Read Berlin datas
ls=list.files()
df=data.frame(Station=NA)

for(elem in ls){
  if(str_sub(elem, start=-4) == ".csv"){
    df_add=read.csv(elem, sep=";")
    df_add=df_add[-c(1:3),c(1,which(df_add[1,]=="Stickstoffdioxid"))]
    
    df=merge(df, df_add, by="Station", all=T)
  }
}
remove(df_add)
df=df[!is.na(df$Station),]

#Convert numeric columns
for(elem in c(2:ncol(df))){
  df[,elem]=as.numeric(df[,elem])
}

#Mean
df["NO2"]=apply(df[,-c(1)],1,mean,na.rm=TRUE)

#Remove useless and rename
df_plot=df[,c(ncol(df),1)]
colnames(df_plot)=c("NO2","Date")

#Mean for each captors by day
df_plot$Date=as.Date(df_plot$Date, format="%d.%m.%Y")


#Fixing empty dates
df_temp=data.frame(Date=seq(min(df_plot$Date), by = "day", length.out = max(df_plot$Date)-min(df_plot$Date)+1))
df_plot=merge(df_temp, df_plot, by="Date", all.x=T)
remove(df_temp)
df_plot$NO2=na.approx(df_plot$NO2)

df_plot["roll_avg"]=c(rep(NA,20),rollmean(df_plot$NO2, 21))

#Compare yearly
df_2019=df_plot[df_plot$Date >= "2019-01-09" & df_plot$Date <= "2019-06-30",]
df_2020=df_plot[df_plot$Date >= "2020-01-09" & df_plot$Date != "2020-02-29" & df_plot$Date <= "2020-06-30",]
df_2020["roll_avg_2019"]=df_2019$roll_avg
df_2020["roll_diff"]=df_2020$roll_avg_2020-df_2019$roll_avg
df_2020["roll_diff_year"]=((df_2020$roll_avg-df_2019$roll_avg)/df_2019$roll_avg)*100


#Plot not corrected
My_Theme = theme(
  axis.title.y = element_text(size = 8))

ggplot(df_2020, aes(Date, roll_diff_year)) + geom_line() + ggtitle("Nitrogen dioxide pollution corrected - Paris") +
  xlab("Date") +
  ylab("Annual variance of the NO2 pollution index (%, 21-day moving average)") +
  scale_x_date(date_breaks = "14 day", date_labels = "%d %b") +
  My_Theme


df_WAQI=df_2020

#Cleaning Environment
rm(list = ls()[ls() != "df_WAQI"])
