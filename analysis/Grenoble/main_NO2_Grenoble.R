setwd("D:/Utilisateur/Documents/Documents/Cours/AMSE M2 S4/COVID19/BdF/Grenoble/")

library("stringr")
library("tidyr")
library("dplyr")
library("ggplot2")
library("reshape2")
library("olsrr")
library("zoo")

#Read and clean grenoble data
df=read.csv("station_grenoble.csv", sep=";", encoding="UTF-8", stringsAsFactors = FALSE)
df=as.data.frame(t(df), stringsAsFactors = FALSE)
colnames(df)=df[1,]
df=df[-c(1),]
for(col in c(2:ncol(df))){
  df[,col]=as.numeric(df[,col])
}
df[,1]=as.Date(df[,1], format="%d/%m/%Y")

#Mean for each captors by day
df["NO2"]=apply(df[,c(2:6)],1,mean)
df_plot=df[,c(ncol(df),1)]
rownames(df_plot)=c(1:nrow(df_plot))

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

ggplot(df_2020, aes(Date, roll_diff_year)) + geom_line() + ggtitle("Nitrogen dioxide pollution corrected - Grenoble") +
  xlab("Date") +
  ylab("Annual variance of the NO2 pollution index (%, 21-day moving average)") +
  scale_x_date(date_breaks = "14 day", date_labels = "%d %b") +
  My_Theme


df_WAQI=df_2020

#Cleaning Environment
rm(list = ls()[ls() != "df_WAQI"])
