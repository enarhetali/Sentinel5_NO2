setwd("D:/Utilisateur/Documents/Documents/Cours/AMSE M2 S4/COVID19/BdF/")
datas_path="../Sentinel5_NO2/datas_sentinel5/archives/"

library("stringr")
library("tidyr")
library("dplyr")
library("ggplot2")
library("reshape2")
library("olsrr")
library("zoo")

#ls=list.files(datas_path)
#df=data.frame()

#for(elem in ls){
#  if(str_sub(elem, start=-7) == ".csv.gz"){
#    df_add=read.csv(paste0(datas_path,elem), sep=",")[ ,-c(1)]
#    df_add=df_add[df_add$cc_pays=="FR" & df_add$cc_region=="Ile-de-France",]
#    df=bind_rows(df_add, df)
#  }
#}
#remove(df_add)

#df["Date"]=as.Date(paste0(df$year, '-', df$month, '-', df$day_mean))
#df=df[,-c(1:3,14:17)]
#df_save=df
#df=df_save

df=read.csv("paris.csv")[,-c(1)]

summary(df)

#Aggregate by IDF
df["coef"]=df$NO2*df$counter

df_agg=df %>% group_by(Date) %>% summarise(coef = sum(coef), counter=sum(counter))
df_agg["NO2"]=df_agg$coef/df_agg$counter
df_agg$Date=as.Date(df_agg$Date)


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
df_2020["roll_avg_2019"]=df_2019$roll_avg
df_2020["roll_diff_year"]=((df_2020$roll_avg-df_2019$roll_avg)/df_2019$roll_avg)*100


#Plot not corrected
My_Theme = theme(
  axis.title.y = element_text(size = 8))

ggplot(df_2020, aes(Date, roll_diff_year)) + geom_line() + ggtitle("Nitrogen dioxide pollution not corrected by satellite meteorological data - Paris") +
  xlab("Date") +
  ylab("Annual variance of the NO2 pollution index (%, 21-day moving average)") +
  scale_x_date(date_breaks = "14 day", date_labels = "%d %b") +
  My_Theme



#Cleaning Environment
rm(list = ls()[!(ls() %in% c("df_WAQI","df_2020","My_Theme"))])

df=merge(df_WAQI[,c(1,6)], df_2020[,c(1,5)], by="Date", all.x=T)
colnames(df)=c("Date","WAQI","Sentinel5")


##
## Stop running here to run ProdIndex.R ##
##

################## STUDY COMBINED SENTINEL5 AND MAIN_NO2 ################## 

ggplot(df, aes(Date)) + 
  geom_line(aes(y = WAQI, colour = "WAQI")) + 
  geom_line(aes(y = Sentinel5, colour = "Sentinel5")) +
  ggtitle("Comparison between WAQI NO2 and Sentinel5 NO2") +
  ylab("Annual variance of the NO2 pollution index (%, 21-day moving average)") +
  scale_x_date(date_breaks = "14 day", date_labels = "%d %b") +
  My_Theme

#Correlation 
cor(df[,-c(1)])

#cross correlation Function
ccf(df$WAQI, df$Sentinel5,100)
cor.test(df$WAQI, lag(df$Sentinel5, 50))

ggplot(df, aes(Date)) + 
  geom_line(aes(y = WAQI, colour = "WAQI")) + 
  geom_line(aes(y = lag(df$Sentinel5,50), colour = "Sentinel5")) +
  ggtitle("Comparison between WAQI NO2 and Sentinel5 NO2 lagged 50 days") +
  ylab("Annual variance of the NO2 pollution index (%, 21-day moving average)") +
  scale_x_date(date_breaks = "14 day", date_labels = "%d %b") +
  My_Theme

