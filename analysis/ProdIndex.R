#Pleas run main_NO2.R and sentinel5.R Before

df_prod=read.csv("INSEE/monthly_values.csv", sep=";")
df_prod$Date=as.Date(paste0(df_prod$Date,"-01"), format="%Y-%m-%d")
df_prod$Raw_manufacturing

#Keep only > 2019
df_prod=df_prod[df_prod$Date >= "2019-01-01",]

#merge with df
df=merge(df, df_prod, by="Date", all=T)

#Cleaning and approxing
df$Raw_industrial=na.approx(df$Raw_industrial)
df$Raw_manufacturing=na.approx(df$Raw_manufacturing)
df=df[!is.na(df$Sentinel5),]

ggplot(df, aes(Date)) + 
  geom_line(aes(y = WAQI, colour = "WAQI")) + 
  geom_line(aes(y = lag(Sentinel5,50), colour = "Sentinel5")) +
  geom_line(aes(y = Raw_industrial, colour = "Raw_industrial")) + 
  geom_line(aes(y = Raw_manufacturing, colour = "Raw_manufacturing")) +
  ggtitle("French production 2015 index") +
  scale_x_date(date_breaks = "14 day", date_labels = "%d %b") +
  My_Theme
