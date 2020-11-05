#Verification encadrement
library(leaflet)


x1=150
x2=50
bound1=0.002000*0.5*x1 #Latitude
bound2=0.002000*x2

leaflet() %>% addTiles() %>%
  addRectangles(
    lng1=df_city_mean[2]-bound2, lat1=df_city_mean[1]-bound1,
    lng2=df_city_mean[2]+bound2, lat2=df_city_mean[1]+bound1,
    fillColor = "transparent",
    color="green"
  ) 


df_city_mean[2]-bound2

df_city_mean[1]-bound1
