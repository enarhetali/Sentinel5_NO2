setwd("D:/Utilisateur/Documents/Documents/Cours/AMSE M2 S4/COVID19/BdF/")

library("stringr")
library("tidyr")
library("dplyr")
library("ggplot2") #
library("reshape2") #
library("olsrr")
library("zoo")

TUC=read.csv("TUC_IDF.csv", sep=";")
colnames(TUC)=c("Date","TUC_Agricole","TUC_Electronique","TUC_Materiel_Transport","TUC_Fab_Industriel","TUC_Manufacture")
TUC$Date=as.Date(TUC$Date, format="%d/%m/%Y")

#Convert numeric columns
for(col in colnames(TUC[,-c(1)])){
  TUC[,col]=gsub(",",".",TUC[,col])
  TUC[,col]=as.numeric(TUC[,col])
}

#Limite Date 01 Decembre 2018
TUC=TUC[TUC$Date >= "2018-01-01",]

#Average
TUC["TUC_global_avg"]=apply(TUC[,-c(1)], 1, mean)

#TUC 2019
TUC_2019=TUC[TUC$Date >= "2019-01-01" & TUC$Date <= "2019-06-01",]
TUC=TUC[TUC$Date >= "2020-01-01" & TUC$Date <= "2020-06-01",]

#Diff By Columns and Date
for(col in colnames(TUC[,-c(1)])){
  TUC[col]=100*((TUC[,col]-TUC_2019[,col])/TUC_2019[,col])
}

remove(TUC_2019)

#Plot
TUC=melt(TUC, id.vars='Date', variable.name='series')

ggplot(TUC, aes(Date,value)) +
  geom_line(aes(colour = series)) +
  ylab("YoY Evolution in %") +
  ggtitle("TUC 2019/2020 Evolution (CVS) - IDF")



#Merge to Paris datas
df=melt(df,  id.vars = 'Date', variable.name = 'series')
df=rbind(df,TUC)

ggplot(df, aes(Date,value)) +
  geom_line(aes(colour = series)) +
  ylab("YoY Evolution in %") +
  ggtitle("TUC 2019/2020 Evolution (CVS) - IDF")

df=dcast(df, Date ~ series)

library(ggcorrplot)
ggcorrplot(cor(df[,-c(1)], use = "na.or.complete"), hc.order = TRUE, type = "lower", lab = TRUE)

#Correlation matrix
ggplot(df_cor, aes(x=x1, y=x2, fill=value))+
  geom_tile() +
  ggtitle("Correlation plot") +
  xlab("") + ylab("") + guides(fill=guide_legend(title="Correlation"))


scatter.smooth(x=df$NO2, y=df$TUC_Agricole, main="Sentinel5 ~ TUC_global_avg")
lmMod <- lm(NO2 ~ TUC_Agricole, data=df)
summary(lmMod)
